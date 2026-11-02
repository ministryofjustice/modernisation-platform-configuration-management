<#
.SYNOPSIS
    Import Remote Desktop Certs to Certificate Store

.DESCRIPTION
    Retrieve certs from S3 bucket
    Retrieve corresponding cert passwords form Secrets Manager
    Import into certificate store

.PARAMETER DomainNameFQDN
    Optionally specify the FQDN of the domain name containing the secrets

.PARAMETER CertFilename
    Specify the name of the certificate to import
#>

[CmdletBinding()]
param (
  [string]$DomainNameFQDN,
  [string]$CertFilename = "star-azure-hmpp-root.pfx"
)

Import-Module ModPlatformAD -Force
Import-Module ModPlatformRemoteDesktop -Force

$LocalCertDir  = "C:\ProgramData\PlatformOperations\pfx"
$S3CertDir     = "s3://mod-platform-image-artefact-bucket20230203091453221500000001/hmpps/dso-certificates/ca-signed/pfx/"
$ADConfig      = Get-ModPlatformADConfig -DomainNameFQDN $DomainNameFQDN
$CertPasswords = Get-ModPlatformADSecret -ModPlatformADConfig $ADConfig -ADConfigSecretKey "CertificatePasswordsSecretName"

if (-not $CertPasswords.ContainsKey($CertFilename)) {
  Write-Error "Certificate secret does not contain password for $CertFilename"
}
$CertPasswordSecureString = ConvertTo-SecureString $CertPasswords[$CertFilename] -AsPlainText -Force

New-Item -ItemType Directory -Path $LocalCertDir -Force | Out-Null
$LocalCertPath = Join-Path $LocalCertDir -ChildPath $CertFilename

aws s3 sync $S3CertDir $LocalCertDir --exclude "*" --include "$CertFilename"

if (-not (Test-Path $LocalCertPath)) {
  Write-Error "S3 bucket doesn't contain cert $CertFilename"
}

$LocalCert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
$LocalCert.Import($LocalCertPath, $CertPasswords[$CertFilename], [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::DefaultKeySet)
$Thumbprint = $LocalCert.Thumbprint
$LocalCert.Dispose()
$ExistingCert = Get-ChildItem -Path "Cert:\LocalMachine\My" | Where-Object { $_.Thumbprint -eq $Thumbprint }

if (-not $ExistingCert) {
  if ($WhatIfPreference) {
    Write-Output "What-If: Importing Cert $CertFilename to Cert:\LocalMachine\My"
  } else {
    Write-Output "Importing Cert $CertFilename to Cert:\LocalMachine\My"
    Import-PfxCertificate -FilePath $LocalCertPath -CertStoreLocation "Cert:\LocalMachine\My" -Password $CertPasswordSecureString
  }
} else {
  Write-Output "Cert $CertFilename already imported to Cert:\LocalMachine\My"
}
