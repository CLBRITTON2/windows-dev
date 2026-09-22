#Requires -Version 7
# Dot-sourced by setup-configs.ps1 and scripts/setup-agent-account.ps1, which link into different homes.

function Link([string]$target, [string]$source, [string]$backupRoot) {
    if (!(Test-Path $source)) {
        Write-Warning "Source missing, skipping: $source"
        return
    }

    $dir = Split-Path $target
    if ($dir -and !(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    if (Test-Path $target) {
        $existing = Get-Item $target -Force
        if ($existing.LinkType) {
            # Windows PowerShell 5.1 cannot remove a junction without -Recurse, and with it deletes the repo
            # files the junction points at (PowerShell/PowerShell#621). Hence #Requires -Version 7.
            Remove-Item $target -Force
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
