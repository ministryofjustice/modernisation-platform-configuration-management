<#
.SYNOPSIS
    Applies the OU and GPO structure to the given domain based on a yaml config file.

.DESCRIPTION
    Either pass in the domain name as a parameter, or derive the AD configuration
    from EC2 tags (environment-name or domain-name).
    EC2 requires permissions to get tags and the aws cli.

.PARAMETER DomainNameFQDN
    Specify the FQDN of the domain name to join

.PARAMETER ConfigFilePath
    Path to the yaml definition of the OU/GPO structure. See ../../Configs/ADConfigDevTest.yaml for example

.EXAMPLE
    ./Set-ModPlatformADOUStructure.ps1 -DomainNameFQDN "test.loc" -ConfigFilePath "../../Configs/ADConfigDevTest.yaml"

.NOTES
    GPO's referenced in the script have to have been created FIRST before running this, otherwise GPO's will not be applied
    
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
