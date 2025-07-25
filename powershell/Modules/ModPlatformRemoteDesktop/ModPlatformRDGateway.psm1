function Add-ModPlatformRDGateway() {
<#
.SYNOPSIS
    Enable Remote Desktop Gateway in HTTP/SSL-Bridging Mode
#>
  [CmdletBinding()]
  param (
    [bool]$DisableUDPTransport = $true,
    [bool]$EnableSSLBridging = $true
  )

  $ErrorActionPreference = "Stop"

  Write-Output "RDGateway: Installing feature if not already installed"
  $InstallRDGatewayResult = Install-WindowsFeature -Name RDS-Gateway -IncludeAllSubFeature  -IncludeManagementTools

  if ($WhatIfPreference -and -Not (Get-Module -ListAvailable -Name RemoteDesktopServices)) {
    Write-Output "What-If: Updating RDGateway settings"
  } else {
    Import-Module RemoteDesktopServices
    $config = Get-CimInstance -ClassName Win32_TSGatewayServerSettings -Namespace root\cimv2\terminalservices
    if ($DisableUDPTransport -eq $true) {
      Write-Output "RDGateway: Disabling udp transport"
      $CimResult = Invoke-CimMethod -MethodName EnableTransport -Arguments @{TransportType=[uint16]2;enable=$false} -InputObject $config
    }
    if ($EnableSSLBridging -eq $true) {
      Write-Output "RDGateway: Enabling ssl-bridging"
      $CimResult = Invoke-CimMethod -MethodName SetSslBridging -Arguments @{SslBridging=[uint32]1} -InputObject $config
    }
  }
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
    if ($WhatIfPreference) {
      Write-Output "What-If: New-Item -Path RDS:\GatewayServer\CAP -Name $Name -AuthMethod $AuthMethod -UserGroups $UserGroups"
    } else {
      New-Item -Path "RDS:\GatewayServer\CAP" -Name $Name -AuthMethod $AuthMethod -UserGroups $UserGroups | out-null
    }
  } else {
    Write-Output "RDGateway: Updating ${Name} CAP"
    if ($WhatIfPreference) {
      Write-Output "What-If: Set-Item -Path RDS:\GatewayServer\CAP\${Name}\AuthMethod -Value $AuthMethod"
    } else {
      Set-Item -Path "RDS:\GatewayServer\CAP\${Name}\AuthMethod" -Value $AuthMethod | out-null
    }
    if (-not (Test-Path -Path "RDS:\GatewayServer\CAP\${Name}\UserGroups\${UserGroups}")) {
      Write-Output "RDGateway: Adding new UserGroups ${UserGroups} to ${Name} CAP"
      New-Item "RDS:\GatewayServer\CAP\${Name}\UserGroups" -Name $UserGroups | out-null
    }
  }
  if ($WhatIfPreference) {
    Write-Output "What-If: Set-Item -Path RDS:\GatewayServer\CAP\${Name}\Status -Value $Status"
  } else {
    Set-Item -Path "RDS:\GatewayServer\CAP\${Name}\Status" -Value $Status | out-null
  }
  if ($IdleTimeout) {
    if ($WhatIfPreference) {
      Write-Output "What-If: Set-Item -Path RDS:\GatewayServer\CAP\${Name}\IdleTimeout -Value $IdleTimeout"
    } else {
      Set-Item -Path "RDS:\GatewayServer\CAP\${Name}\IdleTimeout" -Value $IdleTimeout | out-null
    }
  }
  if ($SessionTimeout -or $SessionTimeoutAction) {
    if ($WhatIfPreference) {
      Write-Output "What-If: Set-Item -Path RDS:\GatewayServer\CAP\${Name}\SessionTimeout -Value $SessionTimeout -SessionTimeoutAction $SessionTimeoutAction"
    } else {
      Set-Item -Path "RDS:\GatewayServer\CAP\${Name}\SessionTimeout" -Value $SessionTimeout -SessionTimeoutAction $SessionTimeoutAction | out-null
    }
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
    if ($WhatIfPreference) {
      Write-Output "What-If: New-Item -Path RDS:\GatewayServer\RAP -Name $Name -ComputerGroupType $ComputerGroupType -UserGroups $UserGroups"
    } else {
      New-Item -Path "RDS:\GatewayServer\RAP" -Name $Name -ComputerGroupType $ComputerGroupType -UserGroups $UserGroups | out-null
    }
  } else {
    Write-Output "RDGateway: Updating ${Name} RAP"
    Set-Item -Path "RDS:\GatewayServer\RAP\${Name}\ComputerGroupType" -Value $ComputerGroupType | out-null
    if (-not (Test-Path -Path "RDS:\GatewayServer\RAP\${Name}\UserGroups\${UserGroups}")) {
      Write-Output "RDGateway: Adding new UserGroups ${UserGroups} to ${Name} RAP"
      if ($WhatIfPreference) {
        Write-Output "What-If: New-Item RDS:\GatewayServer\RAP\${Name}\UserGroups -Name $UserGroups"
      } else {
        New-Item "RDS:\GatewayServer\RAP\${Name}\UserGroups" -Name $UserGroups | out-null
      }
    }
  }
}

Export-ModuleMember -Function Add-ModPlatformRDGateway
Export-ModuleMember -Function Set-ModPlatformRDGatewayCAP
Export-ModuleMember -Function Set-ModPlatformRDGatewayRAP
