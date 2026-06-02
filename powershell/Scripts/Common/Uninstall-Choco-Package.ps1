<#
.SYNOPSIS
    Uninstall a package via Chocolatey

.EXAMPLE
    Uninstall-Choco-Package.ps1 -Package putty
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)][string]$Package,
    [Parameter(Mandatory = $false, Position = 1)][bool]$SkipAutoUninstaller = $true
)

# Check if package is installed using choco list first (more reliable)
Write-Verbose "Checking if $Package is installed..."
$installedPackages = & choco list --local-only --exact $Package | Where-Object { $_ -match "^$Package\s" }

if (-not $installedPackages) {
    Write-Output "$Package is not installed"
    Write-Output 'Skipping uninstall as package is not present'
    return
}

# Fallback: Check whether Chocolatey powershell module is installed for additional verification
$ChocolateyPackage = $null
try {
    if (Get-Module -Name chocolatey -ListAvailable) {
        Write-Verbose 'Chocolatey PowerShell module available, importing module'
        Import-Module -Name chocolatey -Force -ErrorAction SilentlyContinue
        $ChocolateyPackage = Get-ChocolateyPackage -Name $Package -ErrorAction SilentlyContinue
    }
    else {
        Write-Verbose 'Chocolatey PowerShell module not available, will use choco commands directly'
    }
}
catch {
    Write-Verbose "Could not use Chocolatey PowerShell module: $_"
}

# Additional check with PowerShell module (if available)
if (-not $ChocolateyPackage -and (Get-Module -Name chocolatey -ListAvailable)) {
    Write-Output "$Package is not installed"
    Write-Output 'Skipping uninstall as package is not present'
    return
}

# Proceed with uninstall
if ($WhatIfPreference) {
    Write-Output "What-If: Would uninstall $Package"
    if ($SkipAutoUninstaller) {
        choco uninstall $Package -y --skip-autouninstaller --whatif
    }
    else {
        choco uninstall $Package -y --whatif
    }
}
else {
    Write-Output "Uninstalling $Package"
    if ($SkipAutoUninstaller) {
        choco uninstall $Package -y --skip-autouninstaller
    }
    else {
        choco uninstall $Package -y
    }

    # Set exit code based on chocolatey result
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Uninstall of $Package failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}
