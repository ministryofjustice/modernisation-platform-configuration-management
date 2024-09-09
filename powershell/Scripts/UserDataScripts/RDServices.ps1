# EC2AMAZ-6A9OQDH
# EC2AMAZ-9T2GN5H
# EC2AMAZ-KEMMLB6

$GlobalConfig = @{
  "test-win-2022" = @{
    "ConnectionBroker" = "$env:computername.$env:userdnsdomain"
    "LicensingServer" = "ad-azure-rdlic.azure.noms.root"
    "GatewayServer" = "$env:computername.$env:userdnsdomain"
    "GatewayExternalFqdn" = "rdgateway2.test.hmpps-domain.service.justice.gov.uk"
    "RDSessionHosts" = @("EC2AMAZ-9T2GN5H.azure.noms.root")
    "WebAccessServer" = "$env:computername.$env:userdnsdomain"
  }
  "pp-rds" = @{
    "ConnectionBroker" = "$env:computername.$env:userdnsdomain"
    "LicensingServer" = "ad-hmpp-rdlic.azure.noms.root"
    "GatewayServer" = "$env:computername.$env:userdnsdomain"
    "GatewayExternalFqdn" = "rdgateway2.preproduction.hmpps-domain.service.justice.gov.uk"
    "RDSessionHosts" = @("x.azure.hmpp.root")
    "WebAccessServer" = "$env:computername.$env:userdnsdomain"
  }
  "pd-rds" = @{
    "ConnectionBroker" = "$env:computername.$env:userdnsdomain"
    "LicensingServer" = "ad-hmpp-rdlic.azure.noms.root"
    "GatewayServer" = "$env:computername.$env:userdnsdomain"
    "GatewayExternalFqdn" = "rdgateway2.hmpps-domain.service.justice.gov.uk"
    "RDSessionHosts" = @("x.azure.hmpp.root")
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
    [string[]]$Features = ("RDS-Gateway", "RDS-Connection-Broker", "RDS-Web-Access")
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
  if (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-Connection-Broker -ErrorAction SilentlyContinue) {
    Add-RDWebAccessServer -ConnectionBroker $ConnectionBroker -WebAccessServer $WebAccessServer
    # Add-RDSessionHosts -ConnectionBroker $ConnectionBroker -Servers $SessionHosts
  } else {
    Write-Output "${ConnectionBroker}: Creating new RDSession Deployment"
    New-RDSessionDeployment -ConnectionBroker $ConnectionBroker -SessionHost $SessionHosts -WebAccessServer $WebAccessServer
  }
}

function Add-RDLicensingServer {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string]$LicensingServer
  )

  if (-not (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-Licensing | Where-Object -Property Server -EQ $LicensingServer)) {
    Write-Output "${LicensingServer}: Adding RDS-Licensing Server"
    Add-RDServer -ConnectionBroker $ConnectionBroker -Server $LicensingServer -Role RDS-Licensing
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

  Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-Licensing | Where-Object -Property Server -NE $LicensingServerToKeep | ForEach-Object {
    Write-Output ($_.Server + ": Removing RDS-Licensing Server")
    Remove-RDServer -ConnectionBroker $ConnectionBroker -Server $_.Server -Role RDS-Licensing -Force
  }
}

function Add-RDGatewayServer {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string]$GatewayServer,
    [string]$GatewayExternalFqdn
  )

  if (-not (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-Gateway | Where-Object -Property Server -EQ $GatewayServer)) {
    Write-Output "${GatewayServer}: Adding RDS-Gateway Server"
    Add-RDServer -ConnectionBroker $ConnectionBroker -Server $GatewayServer -Role RDS-Gateway -GatewayExternalFqdn $GatewayExternalFqdn
  }

  # TODO use Set-RDDeploymentGatewayConfiguration to update GatewayFQDN
}

function Remove-RDGatewayServer {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string]$GatewayServerToKeep
  )

  Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-Gateway | Where-Object -Property Server -NE $GatewayServerToKeep | ForEach-Object {
    Write-Output ($_.Server + ": Removing RDS-Gateway Server")
    Remove-RDServer -ConnectionBroker $ConnectionBroker -Server $_.Server -Role RDS-Gateway -Force
  }
}

function Add-RDWebAccessServer {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string]$WebAccessServer
  )

  if (-not (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-Web-Access | Where-Object -Property Server -EQ $WebAccessServer)) {
    Write-Output "${WebAccessServer}: Adding RDS-Web-Access Server"
    Add-RDServer -ConnectionBroker $ConnectionBroker -Server $WebAccessServer -Role RDS-Web-Access
  }
}

function Remove-RDWebAccessServer {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string]$WebAccessServerToKeep
  )

  Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-Web-Access | Where-Object -Property Server -NE $WebAccessServerToKeep | ForEach-Object {
    Write-Output ($_.Server + ": Removing RDS-Web-Access Server")
    Remove-RDServer -ConnectionBroker $ConnectionBroker -Server $_.Server -Role RDS-Web-Access -Force
  }
}

$ErrorActionPreference = "Stop"
$Config = Get-Config

Install-RDSWindowsFeatures
Add-RDSessionDeployment -ConnectionBroker $Config.ConnectionBroker -SessionHosts $Config.RDSessionHosts -WebAccessServer $Config.WebAccessServer
Add-RDLicensingServer -ConnectionBroker $Config.ConnectionBroker -LicensingServer $Config.LicensingServer
Add-RDGatewayServer -ConnectionBroker $Config.ConnectionBroker -GatewayServer $Config.GatewayServer -GatewayExternalFqdn $Config.GatewayExternalFqdn

Remove-RDWebAccessServer -ConnectionBroker $Config.ConnectionBroker -WebAccessServerToKeep $WebAccessServer
Remove-RDGatewayServer -ConnectionBroker $Config.ConnectionBroker -GatewayServerToKeep $Config.GatewayServer
Remove-RDLicensingServer -ConnectionBroker $Config.ConnectionBroker -LicensingServerToKeep $Config.LicensingServer
