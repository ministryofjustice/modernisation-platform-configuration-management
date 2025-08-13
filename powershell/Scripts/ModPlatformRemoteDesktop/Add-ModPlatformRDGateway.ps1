<#
.SYNOPSIS
    Configure Remote Desktop Gateway

.DESCRIPTION
    By default derives the AD configuration from EC2 tags (environment-name or domain-name), or specify DomainNameFQDN parameter.
    EC2 requires permissions to get tags and the aws cli.
    Exits with 3010 if reboot required and script requires re-running. For use in SSM docs

.PARAMETER DomainNameFQDN
    Optionally specify the FQDN of the domain name to join

.EXAMPLE
    Add-ModPlatformRDGateway
#>

[CmdletBinding()]
param (
  [string]$DomainNameFQDN,
  [bool]$DisableUDPTransport = $true,
  [bool]$EnableSSLBridging = $true
)

$ErrorActionPreference = "Stop"

Import-Module ModPlatformAD -Force
Import-Module ModPlatformRemoteDesktop -Force

$ADConfig = Get-ModPlatformADConfig -DomainNameFQDN $DomainNameFQDN
$DomainNameNetbios = $ADConfig.DomainNameNetbios

$CAP = @{
  "Name" = "default"
  "AuthMethod" = 1
  "Status" = 1
  "IdleTimeout" = 120
  "SessionTimeout" = 480
  "SessionTimeoutAction" = 0
  "UserGroups" = "Domain Users@${DomainNameNetbios}"
}
$RAP = @{
  "Name" = "default"
  "ComputerGroupType" = 2
  "UserGroups" = "Domain Users@${DomainNameNetbios}"
}

$Feature = Get-WindowsFeature -Name RDS-Gateway
Add-ModPlatformRDGateway -EnableSSLBridging $EnableSSLBridging -DisableUDPTransport $DisableUDPTransport
Set-ModPlatformRDGatewayCAP @CAP
Set-ModPlatformRDGatewayRAP @RAP

if (-not $Feature.Installed) {
  Exit 3010 # triggers reboot on first install otherwise doesn't work
}
