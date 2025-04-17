# Check whether Chocolatey powershell module is installed
# This just makes it easier to get packages, versions and so on
# This isn't installing chocolatey
if (Get-Module -Name chocolatey) {
    Write-Output "Chocolatey PowerShell module installed, importing module"
    Import-Module -Name chocolatey -Force
} else {
    Write-Output "Chocolatey PowerShell module not installed, installing and importing"
    Install-Module -Name chocolatey -Force
    Import-Module -Name chocolatey -Force
}

function Install-Package {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String]
        $Package
    )
    if (Get-ChocolateyPackage -Name $Package) {
        Write-Output "$Package already installed"
        $version = (Get-ChocolateyPackage -Name $Package).version
        Write-Output "$Package version $version installed"
    } else {
        choco install $Package -y
    }
}

Install-Package -Package "putty"
