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
$ADJoinCredential = Get-ModPlatformADJoinCredential -ModPlatformADConfig $ADConfig -ModPlatformADSecret $ADSecret
$Renamed = Rename-ModPlatformADComputer -NewHostname $NewHostname -ModPlatformADCredential $ADJoinCredential
if ($Renamed) {
  Exit 3010 # triggers reboot if running from SSM Doc
}
if (Add-ModPlatformADComputer -ModPlatformADConfig $ADConfig -ModPlatformADCredential $ADJoinCredential) {
  Exit 3010 # triggers reboot if running from SSM Doc
}

$DFSReplicationStatus = Get-Service "DFS Replication" -ErrorAction SilentlyContinue
if ($null -eq $DFSReplicationStatus) {
  $ADAdminCredential = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig -ModPlatformADSecret $ADSecret
  $ADSafeModeAdministratorPassword = Get-ModPlatformADSafeModeAdministratorPassword -ModPlatformADConfig $ADConfig -ModPlatformADSecret $ADSecret
  Install-WindowsFeature -Name AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools
  Install-ADDSDomainController `
   -DomainName $ADConfig.DomainNameFQDN `
   -InstallDns:$true `
   -Credential $ADAdminCredential `
   -SafeModeAdministratorPassword $ADSafeModeAdministratorPassword `
   -NoRebootOnCompletion `
   -NoGlobalCatalog:$false `
   -CreateDnsDelegation:$false `
   -CriticalReplicationOnly:$false `
   -DatabasePath "C:\Windows\NTDS" `
   -LogPath "C:\Windows\NTDS" `
   -SysvolPath "C:\Windows\SYSVOL" `
   -SiteName "Default-First-Site-Name" `
   -Force
  Exit 3010 # triggers reboot if running from SSM Doc
} else {
  $Services='DNS','DFS Replication','Intersite Messaging','Kerberos Key Distribution Center','NetLogon','Active Directory Domain Services'
  ForEach ($Service in $Services) {Get-Service $Service | Select-Object Name, Status}
}
