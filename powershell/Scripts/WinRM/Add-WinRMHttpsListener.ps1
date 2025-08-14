<#
.SYNOPSIS
    Setup winrm HTTPS 5986 listener creating certs if necessary

.DESCRIPTION
    Create or Renew Self-Signed WinRM Cert if necessary
    Create or Update WinRM HTTPS listener
    It's assumed other settings, e.g. firewall and enabling WinRM, are managed via Group Policy

.EXAMPLE
    Add-WinRMHttpsListener
#>

function Set-WinRMListener {
  [CmdletBinding()]
  param (
    [string]$Hostname,
    [string]$Thumbprint
  )

  $ErrorActionPreference = "Continue"
  $WinRmArg1 = "winrm/config/Listener?Address=*+Transport=HTTPS"
  $WinRmArg2 = "'" + '@{Hostname="' + $Hostname + '"; CertificateThumbprint="' + $Thumbprint + '"}' + "'"

  if (Invoke-Expression "winrm get $WinRmArg1") {
    Write-Output "Update winrm https listener"
    if ($WhatIfPreference) {
      Write-Output "What-If: winrm set $WinRmArg1 $WinRmArg2"
    } else {
      Invoke-Expression "winrm set $WinRmArg1 $WinRmArg2"
    }
  } else {
    Write-Output "Create winrm https listener"
    if ($WhatIfPreference) {
      Write-Output "What-If: winrm create $WinRmArg1 $WinRmArg2"
    } else {
      Invoke-Expression "winrm create $WinRmArg1 $WinRmArg2"
    }
  }
}

function Get-WinRMCert {
  [CmdletBinding()]
  param (
    [string]$Hostname
  )
  Get-ChildItem -Path 'Cert:\LocalMachine\My' | Where-Object -Property 'Subject' -match $Hostname | Sort-Object NotAfter | Select-Object -Last 1
}

function New-WinRMCert {
  [CmdletBinding()]
  param (
    [string[]]$Hostnames
  )
  New-SelfSignedCertificate -CertStoreLocation cert:\LocalMachine\My -DnsName $Hostnames -NotAfter (get-date).AddYears(5) -Provider "Microsoft RSA SChannel Cryptographic Provider" -KeyLength 2048
}

$Thumbprint = "MissingCert"
$Hostname   = "$env:computername"
$WinRMCert  = Get-WinRMCert -Hostname $env:computername

if ($WinRMCert) {
  $WinRMCertExpiryDays = ($WinRMCert.NotAfter - (Get-Date)).Days
  if ($WinRMCertExpiryDays -lt 30) {
    Write-Output ("Renewing Self-Signed Cert " + $env:computername + " expiring in $WinRMCertExpiryDays days")
    $WinRMCert = New-WinRMCert -Hostnames ("$env:computername", "$env:computername.$env:userdnsdomain", "localhost")
  }
} else {
  Write-Output ("Creating Self-Signed Cert " + $env:computername)
  $WinRMCert = New-WinRMCert -Hostnames ("$env:computername", "$env:computername.$env:userdnsdomain", "localhost")
}

# extract hostname from cert to ensure it matches
if ($WinRMCert) {
  $Thumbprint = $WinRMCert.Thumbprint
  if ($WinRMCert.Subject -match 'CN=(?<RegexTest>.*?),.*') {
    if ($matches['RegexTest'] -like '*"*') {
      $Hostname = ($Element.Certificate.Subject -split 'CN="(.+?)"')[1]
    } else {
      $Hostnamne = $matches['RegexTest']
    }
  } elseif ($WinRMCert.Subject -match '(?<=CN=).*') {
    $Hostname = $matches[0]
  }
}

Set-WinRMListener -Hostname $Hostname -Thumbprint $Thumbprint
