#Requires -Version 7
#Requires -RunAsAdministrator
<#
.SYNOPSIS
  Create the Hyper-V VM Claude Code runs in, reached from the host over ssh only.

.DESCRIPTION
  Installs Windows 11 Enterprise unattended from its 90-day evaluation ISO, with a local administrator account
  claude that accepts ssh logons only with the key in -AuthorizedKeyPath. The VM sits on the Default Switch behind
  the extended port ACLs of set-agent-vm-acls.ps1, so on any network the laptop joins it reaches the internet but
  not the host, the LAN, or the host's ziti services, and only the host and its other Default Switch VMs can open a
  connection to it, on ssh.

  Runs elevated, so the agent must not be able to change anything it reads: the VM's folder,
  %ProgramData%\<VmName>, must not exist yet (it gets the ACL of Hyper-V's own Virtual Hard Disks folder, minus
  Hyper-V Administrators), and -InstallIso must be in the user profile outside ~\dev, where perusal mirrors the agent's
  edits.

  The guest Administrator password stays in %ProgramData%\<VmName>\administrator.password, for PowerShell Direct
  from the host. claude has the same password, never expiring, and logs on to the guest's desktop at boot, so
  run-in-console.ps1 can run tests that need a desktop. The script restarts the guest last for that.

  Then it trusts the guest's ssh host key in ~\.ssh\known_hosts, and over ssh runs agent-vm-bootstrap.ps1 in the
  guest, which installs git, gh and pwsh, logs gh in with the token this script asks for first, and clones every
  repository under ~\dev into the same path there. Without a Host <VmName> entry in ~\.ssh\config, it adds one for
  <VmName>.mshome.net with the private key beside -AuthorizedKeyPath.

  -PersonalSetupPath is a script with a personal toolchain and dotfiles, such as agent-vm-personal-setup.ps1, that
  the bootstrap runs last in the guest. Without it the VM gets only git, gh, pwsh, Claude Code and herdr.
#>
param(
    [Parameter(Mandatory)] [string] $InstallIso,
    [Parameter(Mandatory)] [string] $AuthorizedKeyPath,
    [Parameter(Mandatory)] [string] $VmName,
    [string] $PersonalSetupPath
)
$ErrorActionPreference = 'Stop'
# Full paths, since this runs elevated and a PATH folder the agent can write could otherwise supply the tool.
$openSshDir = "$env:SystemRoot\System32\OpenSSH"
$git = "$env:ProgramFiles\Git\cmd\git.exe"
$icacls = "$env:SystemRoot\System32\icacls.exe"

# The guest's computer name, which the Default Switch publishes to the host as <name>.mshome.net, is at most 15
# characters.
if ($VmName -notmatch '^[A-Za-z][A-Za-z0-9-]{0,14}$') { throw "VmName must be a computer name of 1 to 15 letters, digits and hyphens: $VmName" }
$vmHost = "$VmName.mshome.net".ToLowerInvariant()
# Holds the VM, its disk, the guest password and the answer file.
$vmDir = Join-Path $env:ProgramData $VmName

# Checked first, so a wrong Host entry does not fail the run after the 45 minute install. Without one, ssh -G gives
# the name itself as the hostname.
$sshSettings = @(& "$openSshDir\ssh.exe" -G $VmName)
if ($LASTEXITCODE -ne 0) { throw "ssh -G $VmName failed (exit $LASTEXITCODE)" }
if ($sshSettings -contains "hostname $($VmName.ToLowerInvariant())") {
    $identityFile = $AuthorizedKeyPath -replace '\.pub$', ''
    if ($identityFile -eq $AuthorizedKeyPath -or -not (Test-Path -LiteralPath $identityFile)) {
        throw "AuthorizedKeyPath must be a .pub file with its private key beside it: $AuthorizedKeyPath"
    }
    $sshConfig = Join-Path $HOME '.ssh\config'
    New-Item -ItemType Directory -Force -Path (Split-Path $sshConfig) | Out-Null
    Add-Content -LiteralPath $sshConfig -Encoding ascii -Value '', "Host $VmName", "  HostName $vmHost", '  User claude',
        "  IdentityFile $identityFile"
    Write-Host "==> added Host $VmName to $sshConfig"
    $sshSettings = @(& "$openSshDir\ssh.exe" -G $VmName)
    if ($LASTEXITCODE -ne 0) { throw "ssh -G $VmName failed (exit $LASTEXITCODE)" }
}
if ($sshSettings -notcontains "hostname $vmHost" -or $sshSettings -notcontains 'user claude') {
    throw "Host $VmName in ~\.ssh\config must have HostName $vmHost and User claude"
}
# ssh looks the host key up under the HostKeyAlias when one is set.
$hostKeyAliasSettings = @($sshSettings -like 'hostkeyalias *')
if ($hostKeyAliasSettings) {
    $knownHostName = $hostKeyAliasSettings[0].Substring('hostkeyalias '.Length)
} else {
    $knownHostName = $vmHost
}

$gitHubToken = Read-Host -AsSecureString "Read-only GitHub token for the agent in $VmName"
if ($gitHubToken.Length -eq 0) { throw 'The GitHub token is empty' }

$isoPath = [IO.Path]::GetFullPath($InstallIso)
if (-not $isoPath.StartsWith("$HOME\", [StringComparison]::OrdinalIgnoreCase) -or
    $isoPath.StartsWith("$HOME\dev\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "InstallIso must be in the user profile outside ~\dev, since the agent's edits reach ~\dev and could replace it. Move the ISO, for example to ~\Downloads: $isoPath"
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

# Checked before the 45 minute install, like the ssh settings above.
$bootstrapPath = Join-Path $PSScriptRoot 'agent-vm-bootstrap.ps1'
if ($PersonalSetupPath) {
    if (-not (Test-Path -LiteralPath $PersonalSetupPath -PathType Leaf)) { throw "PersonalSetupPath is not a file: $PersonalSetupPath" }
    $bootstrapFiles = @($bootstrapPath, $PersonalSetupPath)
    $bootstrapArguments = @('-PersonalSetupPath', (Split-Path -Leaf $PersonalSetupPath))
} else {
    $bootstrapFiles = @($bootstrapPath)
    $bootstrapArguments = @()
}

# One public key line only, so a wrong path cannot copy some other file's content into the guest.
$authorizedKey = (Get-Content -LiteralPath $AuthorizedKeyPath -Raw).Trim()
if ($authorizedKey -notmatch '^(ssh-ed25519|ecdsa-sha2-nistp256|ssh-rsa) [A-Za-z0-9+/]+={0,3}( [^\r\n]*)?$') {
    throw "AuthorizedKeyPath does not hold a single OpenSSH public key: $AuthorizedKeyPath"
}

if (Get-VM -Name $VmName -ErrorAction SilentlyContinue) { throw "VM $VmName already exists" }
# Any user can create a folder under ProgramData and would own it, and an owner can always rewrite its ACL.
if (Test-Path -LiteralPath $vmDir) { throw "$vmDir already exists. Check who owns it, delete it, and rerun" }
New-Item -ItemType Directory -Path $vmDir | Out-Null
& $icacls $vmDir /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)(F)' '*S-1-5-18:(OI)(CI)(F)' `
    '*S-1-5-83-0:(R,WD,AD)' '*S-1-5-83-0:(CI)(IO)(GR,WD,AD)'
if ($LASTEXITCODE -ne 0) { throw "icacls on $vmDir failed (exit $LASTEXITCODE)" }
# Until the line above, the folder inherited ProgramData's grant that lets every user create entries in it.
$strayEntries = @(Get-ChildItem -LiteralPath $vmDir -Force)
if ($strayEntries) { throw "$vmDir got entries before its ACL was set: $($strayEntries.FullName -join ', ')" }

$alphabet = [char[]]'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
# Windows password complexity wants three character classes, here upper case, lower case and digits.
do {
    $passwordBytes = [Security.Cryptography.RandomNumberGenerator]::GetBytes(24)
    $password = -join ($passwordBytes | ForEach-Object { $alphabet[$_ % $alphabet.Length] })
} until ($password -cmatch '[A-Z]' -and $password -cmatch '[a-z]' -and $password -match '[2-9]')
Set-Content -LiteralPath (Join-Path $vmDir 'administrator.password') -NoNewline -Value $password

$answerDir = Join-Path $vmDir 'answer'
New-Item -ItemType Directory -Path $answerDir | Out-Null
(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'agent-vm-autounattend.template.xml') -Raw).
    Replace('__PASSWORD__', $password).Replace('__TIME_ZONE__', (Get-TimeZone).Id).
    Replace('__COMPUTER_NAME__', $VmName.ToUpperInvariant()) |
    Set-Content -LiteralPath (Join-Path $answerDir 'autounattend.xml') -NoNewline

# Setup reads autounattend.xml from the root of any removable media, so the answer file rides on a second DVD.
$answerIso = Join-Path $vmDir 'answer.iso'
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

# 4 GB to start, the least Windows 11 setup takes, so the VM boots beside another one. Dynamic memory grows it.
New-VM -Name $VmName -Generation 2 -MemoryStartupBytes 4GB -NewVHDPath (Join-Path $vmDir "$VmName.vhdx") `
    -NewVHDSizeBytes 120GB -SwitchName 'Default Switch' -Path $vmDir | Out-Null
& (Join-Path $PSScriptRoot 'set-agent-vm-acls.ps1') -VmName $VmName
# ShutDown instead of the default Save, which keeps a file the size of the VM's memory next to it.
Set-VM -Name $VmName -ProcessorCount 12 -DynamicMemory -MemoryMinimumBytes 2GB -MemoryMaximumBytes 10GB `
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

$guestSsh = Invoke-Command -VMName $VmName -Credential $credential -ArgumentList $authorizedKey, $password -ScriptBlock {
    param([string] $authorizedKey, [string] $password)
    $ErrorActionPreference = 'Stop'
    # A desktop session for run-in-console.ps1, since an ssh key logon has no desktop and no DPAPI.
    Set-LocalUser -Name claude -PasswordNeverExpires $true
    $winlogon = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    Set-ItemProperty -LiteralPath $winlogon -Name AutoAdminLogon -Value '1'
    Set-ItemProperty -LiteralPath $winlogon -Name DefaultDomainName -Value $env:COMPUTERNAME
    Set-ItemProperty -LiteralPath $winlogon -Name DefaultUserName -Value 'claude'
    Set-ItemProperty -LiteralPath $winlogon -Name DefaultPassword -Value $password
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
    # The ACLs' stateful ssh rule forgets a connection idle for 255 s, so keep it busier than that.
    $sshdConfig = @('PasswordAuthentication no', 'AllowUsers claude', 'ClientAliveInterval 60') +
        (Get-Content -LiteralPath "$sshDir\sshd_config")
    Set-Content -LiteralPath "$sshDir\sshd_config" -Encoding ascii -Value $sshdConfig
    Set-Content -LiteralPath "$sshDir\administrators_authorized_keys" -Encoding ascii -Value $authorizedKey
    # sshd ignores this file unless only Administrators and SYSTEM can write it.
    & icacls "$sshDir\administrators_authorized_keys" /inheritance:r /grant '*S-1-5-32-544:F' '*S-1-5-18:F'
    if ($LASTEXITCODE -ne 0) { throw "icacls on administrators_authorized_keys failed (exit $LASTEXITCODE)" }
    # Windows puts a network it has not seen in the Public profile, so the rule must not be limited to Private.
    Set-NetFirewallRule -Name OpenSSH-Server-In-TCP -Profile Any -Enabled True
    # The default login shell is cmd, which splits PowerShell pipelines and breaks git's quoted ssh paths.
    # agent-vm-bootstrap.ps1 switches it to pwsh once it has installed it.
    New-ItemProperty -Path HKLM:\SOFTWARE\OpenSSH -Name DefaultShell -PropertyType String -Force `
        -Value "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" | Out-Null
    Restart-Service sshd

    [pscustomobject]@{
        HostKey = (Get-Content -LiteralPath "$sshDir\ssh_host_ed25519_key.pub" -Raw).Trim()
    }
}

# The key came over PowerShell Direct, so ssh never has to trust it on first use. A rebuilt guest has a new one, so
# the old line goes first.
$hostKeyType, $hostKeyData = ($guestSsh.HostKey -split ' ')[0, 1]
$knownHosts = Join-Path $HOME '.ssh\known_hosts'
if (Test-Path -LiteralPath $knownHosts) {
    & "$openSshDir\ssh-keygen.exe" -R $knownHostName -f $knownHosts | Out-Null
    if ($LASTEXITCODE -ne 0) { throw "ssh-keygen -R $knownHostName failed (exit $LASTEXITCODE)" }
}
Add-Content -LiteralPath $knownHosts -Encoding ascii -Value "$knownHostName $hostKeyType $hostKeyData"
Write-Host "==> trusted the host key of $knownHostName in $knownHosts"

# The repositories under ~\dev and where each is cloned from. Each URL is read from the .git\config file, since
# running git in a repository the agent worked in would run what its config names, elevated. Linked work trees
# (a .git file) and the embargoed advisory forks stay out.
$devRoot = Join-Path $HOME 'dev'
$repos = @(Get-Item -Path "$devRoot\*\.git", "$devRoot\*\*\.git" -Force |
    Where-Object { $_.PSIsContainer -and $_.Parent.Name -notlike '*-ghsa-*' -and
        -not (Test-Path -LiteralPath (Join-Path $_.Parent.Parent.FullName '.git')) } |
    ForEach-Object {
        $url = & $git config --file (Join-Path $_.FullName 'config') --get remote.origin.url
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "$($_.Parent.FullName) has no origin, so the VM does not get it"
            return
        }
        if ($url -match '^git@github\.com:(.+?)(\.git)?$') { $url = "https://github.com/$($Matches[1]).git" }
        if ($url -notlike 'https://*') { throw "$($_.Parent.FullName) has an origin the VM cannot clone over https: $url" }
        [pscustomobject]@{ path = $_.Parent.FullName.Substring($devRoot.Length + 1); url = $url }
    })
$gitUserName = & $git config --global user.name
$gitUserEmail = & $git config --global user.email
if (-not $gitUserName -or -not $gitUserEmail) { throw 'git config --global user.name and user.email must be set' }
$setupPath = Join-Path $vmDir 'agent-vm.json'
[pscustomobject]@{ devRoot = $devRoot; gitUserName = $gitUserName; gitUserEmail = $gitUserEmail; repos = $repos } |
    ConvertTo-Json -Depth 3 | Set-Content -LiteralPath $setupPath -Encoding utf8NoBOM

& "$openSshDir\scp.exe" -q @bootstrapFiles $setupPath "${VmName}:"
if ($LASTEXITCODE -ne 0) { throw "scp to $VmName failed (exit $LASTEXITCODE)" }
[Net.NetworkCredential]::new('', $gitHubToken).Password |
    & "$openSshDir\ssh.exe" $VmName powershell -NoProfile -ExecutionPolicy RemoteSigned -File agent-vm-bootstrap.ps1 `
        -SetupPath agent-vm.json @bootstrapArguments
if ($LASTEXITCODE -ne 0) { throw "agent-vm-bootstrap.ps1 in $VmName failed (exit $LASTEXITCODE)" }
# Autologon takes effect at the next boot, and installers such as Visual Studio's ask for one too.
Restart-VM -Name $VmName -Force -Wait -For Heartbeat

Write-Host "==> $VmName is ready. Attach with: herdr --remote $VmName"
Write-Host "    Then run claude in a pane once to log in."
