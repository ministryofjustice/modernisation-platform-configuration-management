<#
.SYNOPSIS
    Install a Domain Controller from scratch

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
  [string]$DomainNameFQDN
)

Import-Module ModPlatformAD -Force

$ErrorActionPreference = "Stop"

$ADConfig = Get-ModPlatformADConfig -DomainNameFQDN $DomainNameFQDN
$ADSecret = Get-ModPlatformADSecret -ModPlatformADConfig $ADConfig

$DFSReplicationStatus = Get-Service "DFS Replication" -ErrorAction SilentlyContinue
if ($DFSReplicationStatus -ne $null) {
  $ADAdminCredential = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig -ModPlatformADSecret $ADSecret
  $ADSafeModeAdministratorPassword = Get-ModPlatformADSafeModeAdministratorPassword -ModPlatformADConfig $ADConfig -ModPlatformADSecret $ADSecret
  Uninstall-ADDSDomainController -Credential $ADAdminCredential -NoRebootOnCompletion -Force
  Exit 3010 # triggers reboot if running from SSM Doc
}
