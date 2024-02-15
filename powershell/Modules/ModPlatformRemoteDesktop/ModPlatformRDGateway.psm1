function Add-ModPlatformRDGateway() {
<#
.SYNOPSIS
    Enable Remote Desktop Gateway in HTTP/SSL-Bridging Mode
#>
  [CmdletBinding()]
  param (
    [hashtable]$RDGatewayFQDN
  )

  $ErrorActionPreference = "Stop"

  Install-WindowsFeature -Name RDS-Gateway -IncludeAllSubFeature  -IncludeManagementTools

  Import-Module RemoteDesktopServices
  $config = Get-CimInstance -ClassName Win32_TSGatewayServerSettings -Namespace root\cimv2\terminalservices
  Write-Output "RDGateway: Disabling udp transport"
  Invoke-CimMethod -MethodName EnableTransport -Arguments @{TransportType=[uint16]2;enable=$false} -InputObject $config
  Write-Output "RDGateway: Enabling ssl-bridging"
  Invoke-CimMethod -MethodName SetSslBridging -Arguments @{SslBridging=[uint32]1} -InputObject $config
}

Export-ModuleMember -Function Add-ModPlatformRDGateway
