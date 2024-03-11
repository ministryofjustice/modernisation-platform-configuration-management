<#
.SYNOPSIS
    Retrieve appropriate AD config for the given Modernisation Platform environment.

.DESCRIPTION
    Either pass in the domain name as a parameter, or derive the AD configuration
    from EC2 tags (environment-name or domain-name).
    EC2 requires permissions to get tags and the aws cli.

.PARAMETER DomainNameFQDN
    Specify the FQDN of the domain name to join

.EXAMPLE
    $ADConfig = Get-ModPlatformADConfig

.OUTPUTS
    
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)][string]$DomainNameFQDN,
    [Parameter(Mandatory=$true)][string]$ConfigFilePath
)

Install-Module -Name powershell-yaml -Force -SkipPublisherCheck

Import-Module ModPlatformAD -Force

Import-Module powershell-yaml -Force

$ParentDN = ($DomainNameFQDN -split "\." | ForEach-Object { "DC=$_" }) -join ","

# Load YAML
$config = Get-Content -Raw -Path $ConfigFilePath | ConvertFrom-Yaml

foreach ($ou in $config.ActiveDirectory.OUs) {
    Set-OUsAndApplyGPOs -OU $Ou -Path $ParentDN
}
