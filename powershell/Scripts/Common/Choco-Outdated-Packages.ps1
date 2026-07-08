<#
.SYNOPSIS
    List all outdated Chocolatey packages

.EXAMPLE
    Get-OutdatedChoco-Packages.ps1
#>

[CmdletBinding()]
param ()

Write-Verbose "Checking for outdated Chocolatey packages..."
$outdatedPackages = choco outdated --limit-output

if (-not $outdatedPackages) {
    Write-Output "All Chocolatey packages are up to date"
    return
}

Write-Output "The following packages are outdated:`n"
Write-Output "Package Name | Current Version | Latest Version"
Write-Output "-------------|-----------------|----------------"

foreach ($line in $outdatedPackages) {
    if (-not $line -or $line -notmatch '\|') {
        continue
    }
    $parts = $line -split '\|'
    $pkgName = $parts[0]
    $currentVersion = $parts[1]
    $latestVersion = $parts[2]
    Write-Output "$pkgName | $currentVersion | $latestVersion"
}