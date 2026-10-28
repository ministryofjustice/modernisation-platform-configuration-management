[CmdletBinding()]
param (
  [string]$DomainNameFQDN
)

Import-Module ModPlatformAD -Force
Import-Module ModPlatformRemoteDesktop -Force

$ADConfig     = Get-ModPlatformADConfig -DomainNameFQDN $DomainNameFQDN
$ADCredential = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig 
