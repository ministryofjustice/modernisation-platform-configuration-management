function Add-ModPlatformRDGateway() {
<#
.SYNOPSIS
    Enable Remote Desktop Gateway in HTTP/SSL-Bridging Mode
#>
  [CmdletBinding()]
  param ()

  $ErrorActionPreference = "Stop"

  Write-Output "RDGateway: Installing feature if not already installed"
  $InstallRDGatewayResult = Install-WindowsFeature -Name RDS-Gateway -IncludeAllSubFeature  -IncludeManagementTools

  Import-Module RemoteDesktopServices
  $config = Get-CimInstance -ClassName Win32_TSGatewayServerSettings -Namespace root\cimv2\terminalservices
  Write-Output "RDGateway: Disabling udp transport"
  $CimResult = Invoke-CimMethod -MethodName EnableTransport -Arguments @{TransportType=[uint16]2;enable=$false} -InputObject $config
  Write-Output "RDGateway: Enabling ssl-bridging"
  $CimResult = Invoke-CimMethod -MethodName SetSslBridging -Arguments @{SslBridging=[uint32]1} -InputObject $config
  return $InstallRDGatewayResult
}

function Set-ModPlatformRDGatewayCAP() {
<#
.SYNOPSIS
    Set Connection Authorization Policy for RDGateway
#>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][string]$Name,
    [int]$AuthMethod = 1,
    [int]$Status = 1,
    [int]$IdleTimeout,
    [int]$SessionTimeout,
    [int]$SessionTimeoutAction,
    [Parameter(Mandatory=$true)][string]$UserGroups
  )

  if (-not (Test-Path -Path "RDS:\GatewayServer\CAP\${Name}")) {
    Write-Output "RDGateway: Creating ${Name} CAP"
    New-Item -Path "RDS:\GatewayServer\CAP" -Name $Name -AuthMethod $AuthMethod -UserGroups $UserGroups | out-null
  } else {
    Write-Output "RDGateway: Updating ${Name} CAP"
    Set-Item -Path "RDS:\GatewayServer\CAP\${Name}\AuthMethod" -Value $AuthMethod | out-null
    if (-not (Test-Path -Path "RDS:\GatewayServer\CAP\${Name}\UserGroups\${UserGroups}")) {
      Write-Output "RDGateway: Adding new UserGroups ${UserGroups} to ${Name} CAP"
      New-Item "RDS:\GatewayServer\CAP\${Name}\UserGroups" -Name $UserGroups | out-null
    }
  }
  Set-Item -Path "RDS:\GatewayServer\CAP\${Name}\Status" -Value $Status | out-null
  if ($IdleTimeout) {
    Set-Item -Path "RDS:\GatewayServer\CAP\${Name}\IdleTimeout" -Value $IdleTimeout | out-null
  }
  if ($SessionTimeout -or $SessionTimeoutAction) {
    Set-Item -Path "RDS:\GatewayServer\CAP\${Name}\SessionTimeout" -Value $SessionTimeout -SessionTimeoutAction $SessionTimeoutAction | out-null
  }
}

function Set-ModPlatformRDGatewayRAP() {
<#
.SYNOPSIS
    Set Resource Authorization Policy for RDGateway
#>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][string]$Name,
    [int]$ComputerGroupType = 2,
    [Parameter(Mandatory=$true)][string]$UserGroups
  )

  if (-not (Test-Path -Path "RDS:\GatewayServer\RAP\${Name}")) {
    Write-Output "RDGateway: Creating ${Name} RAP"
    New-Item -Path "RDS:\GatewayServer\RAP" -Name $Name -ComputerGroupType $ComputerGroupType -UserGroups $UserGroups | out-null
  } else {
    Write-Output "RDGateway: Updating ${Name} RAP"
    Set-Item -Path "RDS:\GatewayServer\RAP\${Name}\ComputerGroupType" -Value $ComputerGroupType | out-null
    if (-not (Test-Path -Path "RDS:\GatewayServer\RAP\${Name}\UserGroups\${UserGroups}")) {
      Write-Output "RDGateway: Adding new UserGroups ${UserGroups} to ${Name} RAP"
      New-Item "RDS:\GatewayServer\RAP\${Name}\UserGroups" -Name $UserGroups | out-null
    }
  }
}

Export-ModuleMember -Function Add-ModPlatformRDGateway
Export-ModuleMember -Function Set-ModPlatformRDGatewayCAP
Export-ModuleMember -Function Set-ModPlatformRDGatewayRAP
