<#
.SYNOPSIS
    Upgrade all outdated Chocolatey packages

.EXAMPLE
    Upgrade-All-Choco-Packages.ps1
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, Position = 0)][string]$Version
)

Write-Verbose "Checking for outdated Chocolatey packages..."
$outdatedPackages = choco outdated --limit-output

if (-not $outdatedPackages) {
    Write-Output "All Chocolatey packages are up to date"
    Write-Output 'Skipping upgrade'
    return
}

$failedPackages = @()

foreach ($line in $outdatedPackages) {
    if (-not $line -or $line -notmatch '\|') {
        continue
    }
    $parts = $line -split '\|'
    $pkgName = $parts[0]
    $currentVersion = $parts[1]
    Write-Output "$pkgName is installed but outdated (current version: $currentVersion)"
    Write-Output 'Proceeding with upgrade...'

    if ($WhatIfPreference) {
        if ($Version) {
            Write-Output "What-If: Would upgrade $pkgName version $Version"
            choco upgrade $pkgName --version=$Version -y --no-progress --whatif
        }
        else {
            Write-Output "What-If: Would upgrade $pkgName (latest version)"
            choco upgrade $pkgName -y --no-progress --whatif
        }
    }
    else {
        if ($Version) {
            Write-Output "Upgrading $pkgName version $Version"
            choco upgrade $pkgName --version=$Version -y --no-progress
        }
        else {
            Write-Output "Upgrading $pkgName (latest version)"
            choco upgrade $pkgName -y --no-progress
        }
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Upgrade of $pkgName failed with exit code $LASTEXITCODE"
            $failedPackages += $pkgName
        }
    }
}

if ($failedPackages.Count -gt 0) {
    Write-Error "Some package upgrades failed: $($failedPackages -join ', ')"
    exit 1
}
