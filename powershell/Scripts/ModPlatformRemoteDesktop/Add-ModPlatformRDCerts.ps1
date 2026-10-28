[CmdletBinding()]
param (
  [string]$DomainNameFQDN
)

Import-Module ModPlatformAD -Force
Import-Module ModPlatformRemoteDesktop -Force

$ADConfig             = Get-ModPlatformADConfig -DomainNameFQDN $DomainNameFQDN
$CertificatePasswords = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig -ADConfigSecretKey "CertificatePasswordsSecretName"

$Path = "C:\ProgramData\PlatformOperations\pfx"
New-Item -ItemType Directory -Path $Path -Force

aws s3 sync "s3://mod-platform-image-artefact-bucket20230203091453221500000001/hmpps/dso-certificates/ca-signed/pfx/" "C:\ProgramData\PlatformOperations\pfx"
