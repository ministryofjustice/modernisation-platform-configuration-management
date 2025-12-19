<#
.SYNOPSIS
    Add or update AD Users

.DESCRIPTION
    Get list of AD Users for the given domain and add or update them.
    Includes adding to relevant AD Group membership.
    EC2 requires permissions to get tags and the aws cli.

.PARAMETER DomainNameFQDN
    Optionally specify the FQDN of the domain name to join, otherwise derived from tag

.EXAMPLE
    Add-ModPlatformADUsers
#>

[CmdletBinding()]
param (
  [string]$DomainNameFQDN
)

Import-Module ModPlatformAD -Force

$ErrorActionPreference = "Stop"

$ADConfig     = Get-ModPlatformADConfig -DomainNameFQDN $DomainNameFQDN
$ADCredential = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig
$ADUsers      = Get-ModPlatformADUserConfig $ADConfig.DomainNameFQDN
Get-ModPlatformADUserCredentials $ADUsers
Add-ModPlatformADUsers $ADConfig $ADUsers $ADCredential
