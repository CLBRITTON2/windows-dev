# Dot-sourced by setup-configs.ps1 and agent-vm-bootstrap.ps1, which link into different homes. Runs under Windows
# PowerShell 5.1 too, since agent-vm-bootstrap.ps1 does.

function Link([string]$target, [string]$source, [string]$backupRoot) {
    if (!(Test-Path $source)) {
        throw "Link source missing: $source (target $target)"
    }

    $dir = Split-Path $target
    if ($dir -and !(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (Test-Path $target) {
        $existing = Get-Item $target -Force
        # Remove-Item in Windows PowerShell 5.1 cannot remove a junction without -Recurse, and with it deletes the
        # repo files the junction points at (PowerShell/PowerShell#621). The .NET calls remove only the link.
        if ($existing.LinkType -and $existing -is [System.IO.DirectoryInfo]) {
            [System.IO.Directory]::Delete($target)
        } elseif ($existing.LinkType) {
            [System.IO.File]::Delete($target)
        } else {
            # Mirror the full target path: several targets share the leaf settings.json.
            $backup = Join-Path $backupRoot ($target -replace '^([A-Za-z]):', '$1')
            New-Item -ItemType Directory -Path (Split-Path $backup) -Force | Out-Null
            Move-Item $target $backup
            Write-Warning "Existing item moved to: $backup"
        }
    }

    $isDir = (Get-Item $source) -is [System.IO.DirectoryInfo]
    if ($isDir) {
        New-Item -ItemType Junction -Path $target -Target $source | Out-Null
    } else {
        New-Item -ItemType SymbolicLink -Path $target -Target $source | Out-Null
    }

    Write-Host "  Linked: $target" -ForegroundColor Green
}
