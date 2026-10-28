<#
.SYNOPSIS
    Set Remote Desktop Host (Terminal Servics) Cert

.DESCRIPTION
    Either the Cert Thumbprint or Cert Name must be provided

.PARAMETER CertThumbprint
    Optionally specify the Thumbprint of the cert

.PARAMETER CertFilename
    Specify the name of the certificate to import
#>

[CmdletBinding()]
param (
  [string]$CertThumbprint,
  [string]$CertName = "*.azure.hmpp.root"
)

if (-not $CertThumbprint) {
  if (-not $CertName) {
    Write-Error "Either CertName or CertThumbprint parameters must be provided"
  }
  $EscapedCertName = [regex]::Escape($CertName)
  $Cert = Get-ChildItem -Path "Cert:\LocalMachine\My" |
    Where-Object { $_.Subject -match "$EscapedCertName" } |
    Sort-Object -Property NotAfter -Descending |
    Select-Object -First 1
  if (-not $Cert) {
    Write-Error "Could not find cert matching $CertName"
  }
  $CertThumbprint = $LatestCert.Thumbprint
} else {
  $Cert = Get-ChildItem -Path "Cert:\LocalMachine\My" |
    Where-Object { $_.Thumbprint -eq $Thumbprint }
  if (-not $Cert) {
    Write-Error "Could not find cert matching $Thumbprint"
  }
}
$Subject    = $Cert.Subject
$ExpiryDate = $Cert.NotAfter

$RDSettings            = Get-WmiObject -Class "Win32_TSGeneralSetting" -Namespace "root\cimv2\TerminalServices" -Filter "TerminalName='RDP-Tcp'"
$CurrentCertThumbprint = $RDSettings.SSLCertificateSHA1Hash
$WmiPath               = $RDSettings.__path

if ($CertThumbprint -eq $CurrentCertThumbprint) {
  Write-Output "RD Host cert already set to $CertThumbprint (subject=$Subject expiry=$ExpiryDate)"
} else {
  if (-not $CurrentCertThumbprint) {
    Write-Output "Setting RD Host cert to $CertThumbprint (subject=$Subject expiry=$ExpiryDate)"
    Set-WmiInstance -Path $WmiPath -Arguments @{SSLCertificateSHA1Hash=$CertThumbprint}
  } else {
    $CurrentCert = Get-ChildItem -Path "Cert:\LocalMachine\My", "Cert:\LocalMachine\Remote Desktop" | Where-Object { $_.Thumbprint -eq $CurrentCertThumbprint } | Select-Object -First 1
    $CurrentSubject    = $CurrentCert.Subject
    $CurrentExpiryDate = $CurrentCert.NotAfter
    Write-Output "Updating RD Host cert $CurrentCertThumbprint (subject=$CurrentSubject expiry=$CurrentExpiryDate) -> $CertThumbprint (subject=$Subject expiry=$ExpiryDate)"
    Set-WmiInstance -Path $WmiPath -Arguments @{SSLCertificateSHA1Hash=$CertThumbprint}
  }
}
