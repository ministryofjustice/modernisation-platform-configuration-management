<#
.SYNOPSIS
    Install a package via Chocolatey 

.EXAMPLE
    Install-Choco-Package.ps1 -Package putty
#>

[CmdletBinding()]
param (
  [Parameter(Mandatory = $true)][string]$Package
)

# Check whether Chocolatey powershell module is installed
# This just makes it easier to get packages, versions and so on
# This isn't installing chocolatey
$ChocolateyPackage = $null
if (Get-Module -Name chocolatey) {
    Write-Verbose "Chocolatey PowerShell module installed, importing module"
    Import-Module -Name chocolatey -Force
    $ChocolateyPackage = Get-ChocolateyPackage -Name $Package
} else {
    Write-Output "Chocolatey PowerShell module not installed, installing and importing"
    Install-Module -Name chocolatey -Force
    if ($WhatIfPreference) {
        Write-Output "What-If: Import-Module -Name chocolatey -Force"
    } else {
        Import-Module -Name chocolatey -Force
        $ChocolateyPackage = Get-ChocolateyPackage -Name $Package
    }
}

if ($ChocolateyPackage) {
    Write-Verbose ("$Package already installed, version: " + $ChocolateyPackage.version)
} elseif ($WhatIfPreference) {
    choco install $Package -y --no-progress --whatif
} else {
    choco install $Package -y --no-progress
}
