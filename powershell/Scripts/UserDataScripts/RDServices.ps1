# EC2AMAZ-IMEOI6S
# EC2AMAZ-M5FEA4N
# EC2AMAZ-C0OVV54

$GlobalConfig = @{
  "test-win-2022" = @{
    "ConnectionBroker" = "$env:computername.$env:userdnsdomain"
    "LicensingServer" = "AD-AZURE-RDLIC.AZURE.NOMS.ROOT"
    "GatewayServer" = "$env:computername.$env:userdnsdomain"
    "GatewayExternalFqdn" = "rdgateway2.test.hmpps-domain.service.justice.gov.uk"
    "SessionHosts" = @("EC2AMAZ-M5FEA4N.AZURE.NOMS.ROOT")
    "WebAccessServer" = "$env:computername.$env:userdnsdomain"
  }
  "pp-rds" = @{
    "ConnectionBroker" = "$env:computername.$env:userdnsdomain"
    "LicensingServer" = "AD-HMPP-RDLIC.AZURE.NOMS.ROOT"
    "GatewayServer" = "$env:computername.$env:userdnsdomain"
    "GatewayExternalFqdn" = "rdgateway2.preproduction.hmpps-domain.service.justice.gov.uk"
    "SessionHosts" = @("x.azure.hmpp.root")
    "WebAccessServer" = "$env:computername.$env:userdnsdomain"
  }
  "pd-rds" = @{
    "ConnectionBroker" = "$env:computername.$env:userdnsdomain"
    "LicensingServer" = "AD-HMPP-RDLIC.AZURE.NOMS.ROOT"
    "GatewayServer" = "$env:computername.$env:userdnsdomain"
    "GatewayExternalFqdn" = "rdgateway2.hmpps-domain.service.justice.gov.uk"
    "SessionHosts" = @("x.azure.hmpp.root")
    "WebAccessServer" = "$env:computername.$env:userdnsdomain"
  }
}

function Get-Config {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $NameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "Name"}).Value

  if (-not $GlobalConfig.Contains($NameTag)) {
    Write-Error "Unexpected Name tag value $NameTag"
  }
  Return $GlobalConfig[$NameTag]
}

function Install-RDSWindowsFeatures {
  [CmdletBinding()]
  param (
    [string[]]$Features = ("RDS-GATEWAY", "RDS-CONNECTION-BROKER", "RDS-WEB-ACCESS")
  )
  $Features | ForEach-Object {
    if (-not (Get-WindowsFeature -Name $_).Installed) {
      Write-Output "Installing $_ Feature"
      Install-WindowsFeature -Name $_ -IncludeAllSubFeature -IncludeManagementTools
    }
  }
}

function Add-RDSessionDeployment {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string[]]$SessionHosts,
    [string]$WebAccessServer
  )
  if (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-CONNECTION-BROKER -ErrorAction SilentlyContinue) {
    Add-RDWebAccessServer -ConnectionBroker $ConnectionBroker -WebAccessServer $WebAccessServer
    Add-SessionHosts -ConnectionBroker $ConnectionBroker -SessionHosts $SessionHosts
  } else {
    Write-Output "${ConnectionBroker}: Creating new RDSession Deployment"
    DSessionDeployment -ConnectionBroker $ConnectionBroker -SessionHost $SessionHosts -WebAccessServer $WebAccessServer
  }
}

function Add-RDLicensingServer {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string]$LicensingServer
  )

  if (-not (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-LICENSING | Where-Object -Property Server -EQ $LicensingServer)) {
    Write-Output "${LicensingServer}: Adding RDS-LICENSING Server"
    Add-RDServer -ConnectionBroker $ConnectionBroker -Server $LicensingServer -Role RDS-LICENSING
  }

  if ((Get-RDLicenseConfiguration -ConnectionBroker $ConnectionBroker).Mode -ne 'PerUser') {
    Write-Output "${LicensingServer}: Setting PerUser LicensingMode"
    Set-RDLicenseConfiguration -ConnectionBroker $ConnectionBroker -LicenseServer $LicensingServer -Mode PerUser -Force
  }
}

function Remove-RDLicensingServer {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string]$LicensingServerToKeep
  )

  Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-LICENSING | Where-Object -Property Server -NE $LicensingServerToKeep | ForEach-Object {
    Write-Output ($_.Server + ": Removing RDS-LICENSING Server")
    Remove-RDServer -ConnectionBroker $ConnectionBroker -Server $_.Server -Role RDS-LICENSING -Force
  }
}

function Add-RDGatewayServer {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string]$GatewayServer,
    [string]$GatewayExternalFqdn
  )

  if (-not (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-GATEWAY | Where-Object -Property Server -EQ $GatewayServer)) {
    Write-Output "${GatewayServer}: Adding RDS-GATEWAY Server"
    Add-RDServer -ConnectionBroker $ConnectionBroker -Server $GatewayServer -Role RDS-GATEWAY -GatewayExternalFqdn $GatewayExternalFqdn
  }

  # TODO use Set-RDDeploymentGatewayConfiguration to update GatewayFQDN
}

function Remove-RDGatewayServer {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string]$GatewayServerToKeep
  )

  Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-GATEWAY | Where-Object -Property Server -NE $GatewayServerToKeep | ForEach-Object {
    Write-Output ($_.Server + ": Removing RDS-GATEWAY Server")
    Remove-RDServer -ConnectionBroker $ConnectionBroker -Server $_.Server -Role RDS-GATEWAY -Force
  }
}

function Add-RDWebAccessServer {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string]$WebAccessServer
  )

  if (-not (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-WEB-ACCESS | Where-Object -Property Server -EQ $WebAccessServer)) {
    Write-Output "${WebAccessServer}: Adding RDS-WEB-ACCESS Server"
    Add-RDServer -ConnectionBroker $ConnectionBroker -Server $WebAccessServer -Role RDS-WEB-ACCESS
  }
}

function Remove-RDWebAccessServer {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string]$WebAccessServerToKeep
  )

  Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-WEB-ACCESS | Where-Object -Property Server -NE $WebAccessServerToKeep | ForEach-Object {
    Write-Output ($_.Server + ": Removing RDS-WEB-ACCESS Server")
    Remove-RDServer -ConnectionBroker $ConnectionBroker -Server $_.Server -Role RDS-WEB-ACCESS -Force
  }
}

function Add-SessionHosts {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string[]]$SessionHosts
  )

  foreach ($SessionHost in $SessionHosts) {
    if (-not (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-RD-SERVER | Where-Object -Property Server -EQ $SessionHost)) {
      Write-Output "${SessionHost}: Adding RDS-RD-SERVER Server"
      Add-RDServer -ConnectionBroker $ConnectionBroker -Server $SessionHost -Role RDS-RD-SERVER
    }
  }
}

function Remove-SessionHosts {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string[]]$SessionHostsToKeep
  )

  Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-RD-SERVER | Where-Object -Property Server -notin $SessionHostsToKeep | ForEach-Object {
    Write-Output ($_.Server + ": Removing RDS-RD-SERVER Server")
    Remove-RDServer -ConnectionBroker $ConnectionBroker -Server $_.Server -Role RDS-RD-SERVER -Force
  }
}

$ErrorActionPreference = "Stop"
$Config = Get-Config

Install-RDSWindowsFeatures
Add-RDSessionDeployment -ConnectionBroker $Config.ConnectionBroker -SessionHosts $Config.SessionHosts -WebAccessServer $Config.WebAccessServer
Add-RDLicensingServer -ConnectionBroker $Config.ConnectionBroker -LicensingServer $Config.LicensingServer
Add-RDGatewayServer -ConnectionBroker $Config.ConnectionBroker -GatewayServer $Config.GatewayServer -GatewayExternalFqdn $Config.GatewayExternalFqdn

Remove-RDWebAccessServer -ConnectionBroker $Config.ConnectionBroker -WebAccessServerToKeep $Config.WebAccessServer
Remove-RDGatewayServer -ConnectionBroker $Config.ConnectionBroker -GatewayServerToKeep $Config.GatewayServer
Remove-RDLicensingServer -ConnectionBroker $Config.ConnectionBroker -LicensingServerToKeep $Config.LicensingServer
Remove-SessionHosts -ConnectionBroker $Config.ConnectionBroker -SessionHostsToKeep $Config.SessionHosts
