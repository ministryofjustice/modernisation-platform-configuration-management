<#
.SYNOPSIS
    Optionally rename and join computer to appropriate Mod Platform domain

.DESCRIPTION
    By default the script derives the hostname from the Name tag. Or specify NewHostname parameter.
    By default derives the AD configuration from EC2 tags (environment-name or domain-name), or specify DomainNameFQDN parameter.
    EC2 requires permissions to get tags and the aws cli.
    Exits with 3010 if reboot required and script requires re-running. For use in SSM docs

.PARAMETER DomainNameFQDN
    Optionally specify the FQDN of the domain name to join

.EXAMPLE
    Join-ModPlatformAD
#>

[CmdletBinding()]
param (
  [string]$NewHostname = "tag:Name",
  [string]$DomainNameFQDN,
  [string]$AccountIdsSSMParameterName = "account_ids"
)

Import-Module ModPlatformAD -Force

$ErrorActionPreference = "Stop"

$ADConfig = Get-ModPlatformADConfig -DomainNameFQDN $DomainNameFQDN
$ADCredential = Get-ModPlatformADCredential -ModPlatformADConfig $ADConfig -AccountIdsSSMParameterName $AccountIdsSSMParameterName
if (Rename-ModPlatformADComputer -NewHostname $NewHostname -ModPlatformADCredential $ADCredential) {
  exit 3010 # triggers reboot if running from SSM Doc
}
if (Add-ModPlatformADComputer -ModPlatformADConfig $ADConfig -ModPlatformADCredential $ADCredential) {
  exit 3010 # triggers reboot if running from SSM Doc
}
