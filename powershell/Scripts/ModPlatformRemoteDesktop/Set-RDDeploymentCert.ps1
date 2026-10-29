<#
.SYNOPSIS
    Set Remote Desktop Certificate by Role

.DESCRIPTION
    Either the Cert Thumbprint or Cert Name must be provided

.PARAMETER CertThumbprint
    Optionally specify the Thumbprint of the cert

.PARAMETER CertFilename
    Specify the name of the certificate to import

.PARAMETER RDRole
    Specify the remote desktop role to set
#>

[CmdletBinding()]
param (
  [string]$CertThumbprint,
  [string]$CertName = "*.azure.hmpp.root",
  [string]$RDRole= "RDPublishing"
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
  $CertThumbprint = $Cert.Thumbprint
} else {
  $Cert = Get-ChildItem -Path "Cert:\LocalMachine\My" | 
    Where-Object { $_.Thumbprint -eq $Thumbprint }
  if (-not $Cert) {
    Write-Error "Could not find cert matching $Thumbprint"
  }
}
$Subject    = $Cert.Subject
$ExpiryDate = $Cert.NotAfter

$CurrentCert           = Get-RDCertificate -Role $RDRole -WhatIf:$false
$CurrentCertThumbprint = $CurrentCert.Thumbprint
if ($CertThumbprint -eq $CurrentCertThumbprint) {
  Write-Output "$RDRole cert already set to $CertThumbprint (subject=$Subject expiry=$ExpiryDate)"
} else {
  if (-not $CurrentCertThumbprint) {
    if ($WhatIfPreference) {
      Write-Output "What-If: Setting $RDRole cert to $CertThumbprint (subject=$Subject expiry=$ExpiryDate)"
    } else {
      Write-Output "Setting $RDRole cert to $CertThumbprint (subject=$Subject expiry=$ExpiryDate)"
      Set-RDCertificate -Role $RDRole -Thumbprint $CertThumbprint -Force
    }
  } else {
    $CurrentSubject    = $CurrentCert.Subject
    $CurrentExpiryDate = $CurrentCert.ExpiresOn
    if ($WhatIfPreference) {
      Write-Output "What-If: Updating $RDRole cert $CurrentCertThumbprint (subject=$CurrentSubject expiry=$CurrentExpiryDate) -> $CertThumbprint (subject=$Subject expiry=$ExpiryDate)"
    } else {
      Write-Output "Updating $RDRole cert $CurrentCertThumbprint (subject=$CurrentSubject expiry=$CurrentExpiryDate) -> $CertThumbprint (subject=$Subject expiry=$ExpiryDate)"
      Set-RDCertificate -Role $RDRole -Thumbprint $CertThumbprint -Force
    }
  }
}
