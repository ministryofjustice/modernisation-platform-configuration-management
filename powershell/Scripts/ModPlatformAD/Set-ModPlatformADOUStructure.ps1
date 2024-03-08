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

Import-Module ModPlatformAD -Force
Import-Module powershell-yaml -Force

# Load YAML
$config = Get-Content -Raw -Path $ConfigFilePath | ConvertFrom-Yaml

Set-OUsAndApplyGPOs -OUs $config.ActiveDirectory.OUs -DomainNameFQDN $config.ActiveDirectory.DomainNameFQDN

