<#
.SYNOPSIS
    Install a Domain Controller from scratch

.DESCRIPTION
    By default the script derives the hostname from the Name tag. Or specify NewHostname parameter.
    By default derives the AD configuration from EC2 tags (environment-name or domain-name), or specify DomainNameFQDN parameter.
    EC2 requires permissions to get tags and the aws cli.
    Exits with 3010 if reboot required and script requires re-running. For use in SSM docs
    Example retrieval of local admin password:
      aws ssm get-parameter --name ec2-user_pem --with-decryption --query Parameter.Value --output text --profile hmpps-domain-services-test > tmp.key
      aws ec2 get-password-data --instance-id i-0aa02abedd9572e19 --profile core-shared-services-production-ad --priv-launch-key tmp.key
      rm tmp.key

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
  Import-Module ADDSDeployment
  $ADAdminCredential = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig -ModPlatformADSecret $ADSecret
  $ADSafeModeAdministratorPassword = Get-ModPlatformADSafeModeAdministratorPassword -ModPlatformADConfig $ADConfig -ModPlatformADSecret $ADSecret
  Uninstall-ADDSDomainController -Credential $ADAdminCredential -NoRebootOnCompletion -DemoteOperationMasterRole -ForceRemoval -Force
  Exit 3010 # triggers reboot if running from SSM Doc
}
