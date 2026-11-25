<#
.SYNOPSIS
    Create self-signed Remote Desktop Certs and import into Certificate Store

.DESCRIPTION
    Generate self-signed cert
    Retrieve corresponding cert passwords form Secrets Manager
    Copy self-signed cert to S3 bucket
    Import into certificate store

.PARAMETER DomainNameFQDN
    Optionally specify the FQDN of the domain name containing the secrets

.PARAMETER CertFilename
    Specify the name of the certificate to import
#>

[CmdletBinding()]
param (
  [string]$CertDNSName,
  [string]$CertFilename,
  [string]$S3CertDir = "s3://s3-bucket20230824125932809600000001/self-signed-certs/pfx/",
  [int]$ExpiryYears = 5
)

Import-Module ModPlatformAD -Force
Import-Module ModPlatformRemoteDesktop -Force

if (-not $CertDNSName) {
  $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
  $CertDNSName = "$($ComputerSystem.Name.ToLower()).$($ComputerSystem.Domain.ToLower())"
  Write-Output "Using $CertDNSName as cert DNS name"
}

if (-not $CertFilename) {
  $CertFilename = "$($CertDNSName.Replace('.', '-')).pfx"
  Write-Output "Using $CertFilename as cert filename"
}

$LocalCertDir = "C:\ProgramData\PlatformOperations\pfx"

New-Item -ItemType Directory -Path $LocalCertDir -Force | Out-Null
$LocalCertPath = Join-Path $LocalCertDir -ChildPath $CertFilename

if (aws s3 ls "${S3CertDir}${CertFilename}" | Out-Null) {
  Write-Output "Cert already exists on S3 ${S3CertDir}${CertFilename} - delete on S3 to force re-generation - skipping"
} elseif (Test-Path $LocalCertPath) {
  Write-Output "Local cert already exists at $LocalCertPath - uploading to ${S3CertDir}${CertFilename}"
  aws s3 sync $LocalCertDir $S3CertDir --exclude "*" --include "$CertFilename"
} else {
  $ADConfig      = Get-ModPlatformADConfig -DomainNameFQDN $DomainNameFQDN
  $CertPasswords = Get-ModPlatformADSecret -ModPlatformADConfig $ADConfig -ADConfigSecretKey "CertificatePasswordsSecretName"

  if (-not $CertPasswords.ContainsKey($CertFilename)) {
    Write-Error "Certificate secret does not contain password for $CertFilename"
  }
  $CertPasswordSecureString = ConvertTo-SecureString $CertPasswords[$CertFilename] -AsPlainText -Force

  Write-Output "Generating self-signed cert for $CertDNSName"
  $Cert = New-SelfSignedCertificate -DnsName $CertDNSName -CertStoreLocation "Cert:\LocalMachine\My" -KeyExportPolicy Exportable -NotAfter (Get-Date).AddYears($ExpiryYears)

  Write-Output "Exporting cert to $LocalCertPath"
  Export-PfxCertificate -Cert $Cert -FilePath $LocalCertPath -Password $CertPasswordSecureString

  Write-Output "Uploading to ${S3CertDir}${CertFilename}"
  aws s3 sync $LocalCertDir $S3CertDir --exclude "*" --include "$CertFilename"
}
