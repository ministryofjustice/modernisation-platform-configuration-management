<#
.SYNOPSIS
    Upgrade a package via Chocolatey

.EXAMPLE
    Upgrade-Choco-Package.ps1 -Package putty
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)][string]$Package,
    [Parameter(Mandatory = $false, Position = 1)][string]$Version
)

# Check if package is already installed using choco list first (more reliable)
Write-Verbose "Checking if $Package is already installed..."
$installedPackage = choco list --local-only | Where-Object { $_ -match "^$Package\s" }

# Fallback: Check whether Chocolatey PowerShell module is installed
if (-not $installedPackage) {
    Write-Verbose 'Package not found via choco list, trying Chocolatey PowerShell module'
    try {
        if (Get-Module -Name chocolatey -ListAvailable) {
            Write-Verbose 'Chocolatey PowerShell module available, importing module'
            Import-Module -Name chocolatey -Force -ErrorAction SilentlyContinue
            $ChocolateyPackage = Get-ChocolateyPackage -Name $Package -ErrorAction SilentlyContinue
            if ($ChocolateyPackage) {
                $installedPackage = "$($ChocolateyPackage.Name) $($ChocolateyPackage.Version)"
            }
        }
        else {
            Write-Verbose 'Chocolatey PowerShell module not available'
        }
    }
    catch {
        Write-Verbose "Could not use Chocolatey PowerShell module: $_"
    }
}

# Package still not installed
if (-not $installedPackage) {
    Write-Output "$Package is not installed"
    return
}

$installedVersion = ($installedPackage -split '\s+')[1]
Write-Verbose "Checking if $Package has updates available..."
$outdatedPackage = choco outdated $Package --limit-output

if (-not $outdatedPackage) {
    Write-Output "$Package is already installed and up to date (version $installedVersion)"
    Write-Output 'Skipping upgrade'
    return
}

Write-Output "$Package is installed but outdated (current version: $installedVersion)"
Write-Output 'Proceeding with upgrade...'

# Proceed with upgrade
if ($WhatIfPreference) {
    if ($Version) {
        Write-Output "What-If: Would upgrade $Package version $Version"
        choco upgrade $Package --version=$Version -y --no-progress --whatif
    }
    else {
        Write-Output "What-If: Would upgrade $Package (latest version)"
        choco upgrade $Package -y --no-progress --whatif
    }
}
else {
    if ($Version) {
        Write-Output "Upgrading $Package version $Version"
        choco upgrade $Package --version=$Version -y --no-progress
    }
    else {
        Write-Output "Upgrading $Package (latest version)"
        choco upgrade $Package -y --no-progress
    }

    # Set exit code based on chocolatey result
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Upgrade of $Package failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}
