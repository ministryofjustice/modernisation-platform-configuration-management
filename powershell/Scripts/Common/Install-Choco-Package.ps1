<#
.SYNOPSIS
    Install a package via Chocolatey 

.EXAMPLE
    Install-Choco-Package.ps1 -Package putty
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)][string]$Package,
    [Parameter(Mandatory = $false, Position = 1)][string]$Version
)

# Check if package is already installed using choco list first (more reliable)
Write-Verbose "Checking if $Package is already installed..."
$installedPackages = & choco list --local-only | Where-Object { $_ -match "^$Package\s" }

if ($installedPackages) {
    $installedVersion = ($installedPackages -split '\s+')[1]
    Write-Output "$Package is already installed, version: $installedVersion"
    Write-Output 'Skipping installation as package is already present'
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
if ($ChocolateyPackage) {
    Write-Output ("$Package already confirmed installed via PowerShell module, version: " + $ChocolateyPackage.version)
    return
}

# Proceed with installation
if ($WhatIfPreference) {
    if ($Version) {
        Write-Output "What-If: Would install $Package version $Version"
        choco install $Package --version=$Version -y --no-progress --whatif
    }
    else {
        Write-Output "What-If: Would install $Package (latest version)"
        choco install $Package -y --no-progress --whatif
    }
}
else {
    if ($Version) {
        Write-Output "Installing $Package version $Version"
        choco install $Package --version=$Version -y --no-progress
    }
    else {
        Write-Output "Installing $Package (latest version)"
        choco install $Package -y --no-progress
    }
    
    # Set exit code based on chocolatey result
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Installation of $Package failed with exit code $LASTEXITCODE"
        exit $LASTEXITCODE
    }
}
