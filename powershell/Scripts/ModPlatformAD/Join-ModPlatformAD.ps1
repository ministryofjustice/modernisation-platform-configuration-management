<#
.SYNOPSIS
    Join computer to appropriate Mod Platform domain

.DESCRIPTION
    Either pass in the doman name as a parameter, or derive the AD configuration 
    from EC2 tags (environment-name or domain-name).          
    EC2 requires permissions to get tags and the aws cli.
    Exits with 3010 if reboot required and script requires re-running. For use in SSM docs

.PARAMETER DomainNameFQDN
    Optionally specify the FQDN of the domain name to join

.EXAMPLE
    Join-ModPlatformAD
#>

[CmdletBinding()]
param (
  [string]$DomainNameFQDN
  [string]$AccountIdsSSMParameterName = "account_ids"
)

Import-Module ModPlatformADConfig
Import-Module ModPlatformADCredential
Import-Module ModPlatformADComputer

Write-Output "ok"
exit 1

$ErrorActionPreference = "Stop"

$ADConfig = Get-ModPlatformADConfig -DomainNameFQDN $DomainNameFQDN
$ADCredential = Get-ModPlatformADCredential -ModPlatformADConfig $ADConfig -AccountIdsSSMParameterName $AccountIdsSSMParameterName
if (Rename-ModPlatformADComputer -NewHostname "tag:Name" -ModPlatformADCredential $ADCredential) {
  exit 3010 # triggers reboot if running from SSM Doc
}
if (Add-ModPlatformADComputer -$ModPlatformADConfig $ADConfig -ModPlatformADCredential $ADCredential) {
  exit 3010 # triggers reboot if running from SSM Doc
}
