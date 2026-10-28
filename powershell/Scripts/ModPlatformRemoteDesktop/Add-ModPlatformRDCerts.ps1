[CmdletBinding()]
param (
  [string]$DomainNameFQDN
)

Import-Module ModPlatformAD -Force
Import-Module ModPlatformRemoteDesktop -Force

$ADConfig             = Get-ModPlatformADConfig -DomainNameFQDN $DomainNameFQDN
$CertificatePasswords = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig -ADConfigSecretKey "CertificatePasswordsSecretName"
