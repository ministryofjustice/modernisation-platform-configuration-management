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
    [Parameter(Mandatory=$true)][string]$DomainNameFQDN
)

Import-Module ModPlatformAD -Force
Import-Module powershell-yaml -Force

$configFileName = ""

switch($DomainNameFQDN) {
    "prod.loc" {
        $configFileName = "ADConfigProdPreProd.yaml"
    }
    "test.loc" {
        $configFileName = "ADConfigDevTest.yaml"
    }
    default {
        Write-Error "Invalid input value. Please provide either 'azure.hmpp.root' (Prod/PreProd) or 'azure.noms.root' (Dev/Test)."
        exit 1
    }
}

# Load YAML
$yaml = Get-Content -Raw -Path $PSScriptRoot + "\$configFileName"
$config = ConvertFrom-Yaml -InputObject $yaml

Set-OUsAndApplyGPOs -OUs $config.ActiveDirectory.OUs -DomainNameFQDN $config.ActiveDirectory.DomainNameFQDN

