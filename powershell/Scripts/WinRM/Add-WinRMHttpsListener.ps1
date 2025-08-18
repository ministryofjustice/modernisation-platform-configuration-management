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
  Get-ChildItem -Path 'Cert:\LocalMachine\My' | Where-Object -Property 'Subject' -Like "CN*=*$Hostname" | Sort-Object NotAfter | Select-Object -Last 1
}

function New-WinRMCert {
  [CmdletBinding()]
  param (
    [string[]]$Hostnames
  )
  New-SelfSignedCertificate -CertStoreLocation cert:\LocalMachine\My -DnsName $Hostnames -NotAfter (get-date).AddYears(5) -Provider "Microsoft RSA SChannel Cryptographic Provider" -KeyLength 2048
}

function Set-WinRMCertAndListener {
  [CmdletBinding()]
  param (
    [string]$Hostname
  )

  $Thumbprint = "MissingCert"
  $WinRMCert  = Get-WinRMCert -Hostname $Hostname

  if ($WinRMCert) {
    $WinRMCertExpiryDays = ($WinRMCert.NotAfter - (Get-Date)).Days
    if ($WinRMCertExpiryDays -lt 30) {
      Write-Output ("Renewing Self-Signed Cert " + $env:computername + " expiring in $WinRMCertExpiryDays days")
      $WinRMCert = New-WinRMCert -Hostnames ("$Hostname")
    }
  } else {
    Write-Output ("Creating Self-Signed Cert " + $env:computername)
    $WinRMCert = New-WinRMCert -Hostnames ("$Hostname")
  }
  if ($WinRMCert) {
    $Thumbprint = $WinRMCert.Thumbprint
  }
  Set-WinRMListener -Hostname $Hostname -Thumbprint $Thumbprint
}

# systeminfo is more reliable for getting domain name than $env
$DomainName = (systeminfo | Select-String -Pattern 'Domain:[ ]+([\w\.]+)') -match 'Domain:[ ]+([\w\.]+)'
if ($DomainName) {
  Set-WinRMCertAndListener "$env:computername.$DomainName"
} else {
  Set-WinRMCertAndListener $env:computername
}
