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
    Invoke-Expression "winrm set $WinRmArg1 $WinRmArg2"
  } else {
    Write-Output "Create winrm https listener"
    Invoke-Expression "winrm create $WinRmArg1 $WinRmArg2"
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

$WinRMCert = Get-WinRMCert -Hostname $env:computername
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

Set-WinRMListener -Hostname "$env:computername" -Thumbprint $WinRMCert.Thumbprint
