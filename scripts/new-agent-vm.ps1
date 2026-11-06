#Requires -Version 7
#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Create the Hyper-V VM Claude Code runs in, reached from the host over ssh only.

.DESCRIPTION
  Installs Windows 11 Enterprise unattended from its 90-day evaluation ISO, with a local administrator account
  claude that accepts ssh logons only with the key in -AuthorizedKeyPath. The VM sits on the Default Switch behind
  the extended port ACLs of set-agent-vm-acls.ps1, so on any network the laptop joins it reaches the internet but
  not the host, the LAN, or the owner's ziti services, and only the host and its other Default Switch
  VMs can open a connection to it, on ssh.

  Runs elevated, so the agent account on the host must not be able to change anything it reads: -VmDir must not
  exist yet (it gets the ACL of Hyper-V's own Virtual Hard Disks folder, minus Hyper-V Administrators), and
  -InstallIso must be in your profile outside ~\dev. Keep this script in $ownerExecPaths in setup-claude.ps1.

  The guest Administrator password stays in -VmDir\administrator.password, for PowerShell Direct from the host.
#>
param(
    [Parameter(Mandatory)] [string] $InstallIso,
    [Parameter(Mandatory)] [string] $AuthorizedKeyPath,
    [Parameter(Mandatory)] [string] $VmName,
    [Parameter(Mandatory)] [string] $VmDir
)
$ErrorActionPreference = 'Stop'

$isoPath = [IO.Path]::GetFullPath($InstallIso)
if (-not $isoPath.StartsWith("$HOME\", [StringComparison]::OrdinalIgnoreCase) -or
    $isoPath.StartsWith("$HOME\dev\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "InstallIso must be in your profile outside ~\dev, where the agent account cannot replace it: $isoPath"
}
# A path that leads to some other file must not hand that file to the guest as a disc. ISO 9660 puts CD001 at 32769.
$isoStream = [IO.File]::OpenRead($isoPath)
try {
    $isoStream.Position = 32769
    $isoSignature = [byte[]]::new(5)
    $isoStream.ReadExactly($isoSignature, 0, 5)
} finally {
    $isoStream.Dispose()
}
if ([Text.Encoding]::ASCII.GetString($isoSignature) -ne 'CD001') { throw "InstallIso is not an ISO 9660 image: $isoPath" }

# One public key line only, so a wrong path cannot copy some other file's content into the guest.
$authorizedKey = (Get-Content -LiteralPath $AuthorizedKeyPath -Raw).Trim()
if ($authorizedKey -notmatch '^(ssh-ed25519|ecdsa-sha2-nistp256|ssh-rsa) [A-Za-z0-9+/]+={0,3}( [^\r\n]*)?$') {
    throw "AuthorizedKeyPath does not hold a single OpenSSH public key: $AuthorizedKeyPath"
}

if (Get-VM -Name $VmName -ErrorAction SilentlyContinue) { throw "VM $VmName already exists" }
# Any user can create a folder under ProgramData and would own it, and an owner can always rewrite its ACL.
if (Test-Path -LiteralPath $VmDir) { throw "$VmDir already exists. Check who owns it, delete it, and rerun" }
New-Item -ItemType Directory -Path $VmDir | Out-Null
& icacls $VmDir /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)(F)' '*S-1-5-18:(OI)(CI)(F)' `
    '*S-1-5-83-0:(R,WD,AD)' '*S-1-5-83-0:(CI)(IO)(GR,WD,AD)'
if ($LASTEXITCODE -ne 0) { throw "icacls on $VmDir failed (exit $LASTEXITCODE)" }
# Until the line above, the folder inherited ProgramData's grant that lets every user create entries in it.
$strayEntries = @(Get-ChildItem -LiteralPath $VmDir -Force)
if ($strayEntries) { throw "$VmDir got entries before its ACL was set: $($strayEntries.FullName -join ', ')" }

$alphabet = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
$passwordBytes = [Security.Cryptography.RandomNumberGenerator]::GetBytes(20)
$password = 'Cv1!' + (-join ($passwordBytes | ForEach-Object { $alphabet[$_ % $alphabet.Length] }))
Set-Content -LiteralPath (Join-Path $VmDir 'administrator.password') -NoNewline -Value $password

$answerDir = Join-Path $VmDir 'answer'
New-Item -ItemType Directory -Path $answerDir | Out-Null
(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'agent-vm-autounattend.template.xml') -Raw).
    Replace('__PASSWORD__', $password).Replace('__TIME_ZONE__', (Get-TimeZone).Id) |
    Set-Content -LiteralPath (Join-Path $answerDir 'autounattend.xml') -NoNewline

# Setup reads autounattend.xml from the root of any removable media, so the answer file rides on a second DVD.
$answerIso = Join-Path $VmDir 'answer.iso'
Add-Type -TypeDefinition @"
using System;
using System.IO;
using System.Runtime.InteropServices.ComTypes;
public static class IsoStreamWriter {
    public static void Write(object stream, string path) {
        IStream source = (IStream)stream;
        using (FileStream target = File.Create(path)) {
            byte[] buffer = new byte[65536];
            IntPtr readPtr = System.Runtime.InteropServices.Marshal.AllocHGlobal(4);
            try {
                while (true) {
                    source.Read(buffer, buffer.Length, readPtr);
                    int read = System.Runtime.InteropServices.Marshal.ReadInt32(readPtr);
                    if (read == 0) break;
                    target.Write(buffer, 0, read);
                }
            } finally { System.Runtime.InteropServices.Marshal.FreeHGlobal(readPtr); }
        }
    }
}
"@
$fileSystemImage = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
$fileSystemImage.FileSystemsToCreate = 3  # ISO9660 + Joliet
$fileSystemImage.VolumeName = 'ANSWER'
$fileSystemImage.Root.AddTree($answerDir, $false)
[IsoStreamWriter]::Write($fileSystemImage.CreateResultImage().ImageStream, $answerIso)

New-VM -Name $VmName -Generation 2 -MemoryStartupBytes 8GB -NewVHDPath (Join-Path $VmDir "$VmName.vhdx") `
    -NewVHDSizeBytes 120GB -SwitchName 'Default Switch' -Path $VmDir | Out-Null
& (Join-Path $PSScriptRoot 'set-agent-vm-acls.ps1') -VmName $VmName
# ShutDown instead of the default Save, which keeps a file the size of the VM's memory next to it.
Set-VM -Name $VmName -ProcessorCount 12 -DynamicMemory -MemoryMinimumBytes 8GB -MemoryMaximumBytes 16GB `
    -AutomaticCheckpointsEnabled $false -AutomaticStopAction ShutDown
Set-VMFirmware -VMName $VmName -SecureBootTemplate MicrosoftWindows
# Windows 11 setup refuses a machine without TPM 2.0.
Set-VMKeyProtector -VMName $VmName -NewLocalKeyProtector
Enable-VMTPM -VMName $VmName
$installDvd = Add-VMDvdDrive -VMName $VmName -Path $isoPath -Passthru
Add-VMDvdDrive -VMName $VmName -Path $answerIso
Set-VMFirmware -VMName $VmName -FirstBootDevice $installDvd

Start-VM -Name $VmName
# The Gen2 boot loader waits a few seconds for "Press any key to boot from CD or DVD", so keep pressing Enter.
$computerSystem = Get-CimInstance -Namespace root\virtualization\v2 -ClassName Msvm_ComputerSystem -Filter "ElementName='$VmName'"
$keyboard = Get-CimAssociatedInstance -InputObject $computerSystem -ResultClassName Msvm_Keyboard
for ($i = 0; $i -lt 20; $i++) {
    Invoke-CimMethod -InputObject $keyboard -MethodName TypeKey -Arguments @{ keyCode = [uint32]13 } | Out-Null
    Start-Sleep -Milliseconds 500
}

$credential = [pscredential]::new('Administrator', (ConvertTo-SecureString $password -AsPlainText -Force))
$deadline = (Get-Date).AddMinutes(45)
$lastError = 'none'
while ($true) {
    if ((Get-Date) -gt $deadline) { throw "VM $VmName did not finish setup within 45 minutes. Last error: $lastError" }
    # Until setup sets the Administrator password, PowerShell Direct fails with errors that differ by stage.
    try {
        $imageState = Invoke-Command -VMName $VmName -Credential $credential -ErrorAction Stop -ScriptBlock {
            (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\State).ImageState
        }
        # PowerShell Direct works during OOBE, which restarts the guest once more before it is done.
        if ($imageState -eq 'IMAGE_STATE_COMPLETE') { break }
        $lastError = "setup state $imageState"
    } catch {
        $lastError = $_.Exception.Message
    }
    Write-Host "==> waiting for $VmName ($lastError)"
    Start-Sleep -Seconds 30
}
Get-VMDvdDrive -VMName $VmName | Set-VMDvdDrive -Path $null

$guestSsh = Invoke-Command -VMName $VmName -Credential $credential -ArgumentList $authorizedKey -ScriptBlock {
    param([string] $authorizedKey)
    $ErrorActionPreference = 'Stop'
    # The ACLs on the VM's adapter deny the Default Switch's DNS proxy on the host.
    $guestAdapter = Get-NetAdapter | Where-Object InterfaceDescription -like 'Microsoft Hyper-V Network Adapter*'
    Set-DnsClientServerAddress -InterfaceIndex $guestAdapter.ifIndex -ServerAddresses 1.1.1.1, 9.9.9.9
    # An evaluation that is not activated shuts itself down an hour after every boot.
    $activationOutput = & cscript //nologo "$env:SystemRoot\System32\slmgr.vbs" /ato
    # 55c92734-d682-4d71-983e-d6ec3f16059f is the ApplicationID of Windows itself, and LicenseStatus 1 is Licensed.
    $windowsLicense = Get-CimInstance SoftwareLicensingProduct `
        -Filter "ApplicationID = '55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL"
    if ($windowsLicense.LicenseStatus -ne 1) {
        throw "Windows activation failed, LicenseStatus $($windowsLicense.LicenseStatus): $activationOutput"
    }
    $sshDir = "$env:ProgramData\ssh"
    # Windows 11 does not install OpenSSH Server, and this pulls it from Windows Update.
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 | Out-Null
    Set-Service sshd -StartupType Automatic
    # The first start writes the host keys and copies sshd_config_default to sshd_config.
    Start-Service sshd
    # sshd keeps the first value it reads for a keyword, so these go above the defaults.
    $sshdConfig = @('PasswordAuthentication no', 'AllowUsers claude') + (Get-Content -LiteralPath "$sshDir\sshd_config")
    Set-Content -LiteralPath "$sshDir\sshd_config" -Encoding ascii -Value $sshdConfig
    Set-Content -LiteralPath "$sshDir\administrators_authorized_keys" -Encoding ascii -Value $authorizedKey
    # sshd ignores this file unless only Administrators and SYSTEM can write it.
    & icacls "$sshDir\administrators_authorized_keys" /inheritance:r /grant '*S-1-5-32-544:F' '*S-1-5-18:F'
    if ($LASTEXITCODE -ne 0) { throw "icacls on administrators_authorized_keys failed (exit $LASTEXITCODE)" }
    # Windows puts a network it has not seen in the Public profile, so the rule must not be limited to Private.
    Set-NetFirewallRule -Name OpenSSH-Server-In-TCP -Profile Any -Enabled True
    Restart-Service sshd

    [pscustomobject]@{
        HostKey = & "$env:SystemRoot\System32\OpenSSH\ssh-keygen.exe" -lf "$sshDir\ssh_host_ed25519_key.pub"
    }
}
# The answer file names the guest CLAUDE-VM, which the Default Switch publishes to the host under mshome.net.
Write-Host "==> $VmName is installed. ssh to it as claude at claude-vm.mshome.net."
Write-Host "    host key: $($guestSsh.HostKey)"
