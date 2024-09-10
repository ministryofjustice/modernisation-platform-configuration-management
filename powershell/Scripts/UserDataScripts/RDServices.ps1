# EC2AMAZ-5MM4HLA
# EC2AMAZ-F67RQTG

$GlobalConfig = @{
  "test-win-2022" = @{
    "ConnectionBroker" = "$env:computername.$env:userdnsdomain"
    "LicensingServer" = "AD-AZURE-RDLIC.AZURE.NOMS.ROOT"
    "GatewayServer" = "$env:computername.$env:userdnsdomain"
    "GatewayExternalFqdn" = "rdgateway2.test.hmpps-domain.service.justice.gov.uk"
    "SessionHostServers" = @("EC2AMAZ-5MM4HLA.AZURE.NOMS.ROOT")
    "WebAccessServer" = "$env:computername.$env:userdnsdomain"
    "Collections" = @{
      "CAFM-RDP" = @{
        "SessionHosts" = @("EC2AMAZ-5MM4HLA.AZURE.NOMS.ROOT")
        "Configuration" = @{
          "CollectionDescription" = "PlanetFM RemoteDesktop App Collection 2"
          "UserGroup" = @("azure\drobinson")
        }
      }
    }
    "RemoteApps" = @{
      "Calc" = @{
        "CollectionName" = "CAFM-RDP"
        "DisplayName" = "Calc2022"
        "FilePath" = 'C:\Windows\System32\win32calc.exe'
      }
    }
  }
  "pp-rds" = @{
    "ConnectionBroker" = "$env:computername.$env:userdnsdomain"
    "LicensingServer" = "AD-HMPP-RDLIC.AZURE.NOMS.ROOT"
    "GatewayServer" = "$env:computername.$env:userdnsdomain"
    "GatewayExternalFqdn" = "rdgateway2.preproduction.hmpps-domain.service.justice.gov.uk"
    "SessionHostServers" = @("x.azure.hmpp.root")
    "WebAccessServer" = "$env:computername.$env:userdnsdomain"
  }
  "pd-rds" = @{
    "ConnectionBroker" = "$env:computername.$env:userdnsdomain"
    "LicensingServer" = "AD-HMPP-RDLIC.AZURE.NOMS.ROOT"
    "GatewayServer" = "$env:computername.$env:userdnsdomain"
    "GatewayExternalFqdn" = "rdgateway2.hmpps-domain.service.justice.gov.uk"
    "SessionHostServers" = @("x.azure.hmpp.root")
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
    [string[]]$SessionHostServers,
    [string]$WebAccessServer
  )
  if (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-CONNECTION-BROKER -ErrorAction SilentlyContinue) {
    Add-RDWebAccessServer -ConnectionBroker $ConnectionBroker -WebAccessServer $WebAccessServer
    Add-SessionHostServer -ConnectionBroker $ConnectionBroker -SessionHostServers $SessionHostServers
  } else {
    Write-Output "${ConnectionBroker}: Creating new RDSession Deployment"
    New-RDSessionDeployment -ConnectionBroker $ConnectionBroker -SessionHost $SessionHostServers -WebAccessServer $WebAccessServer
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

  $GatewayConfig = Get-RDDeploymentGatewayConfiguration -ConnectionBroker $ConnectionBroker
  if ($GatewayConfig.GatewayExternalFQDN -ne $GatewayExternalFqdn) {
    Write-Output "${GatewayServer}: Updating FQDN: ${GatewayExternalFqdn}"
    Set-RDDeploymentGatewayConfiguration -ConnectionBroker $ConnectionBroker -GatewayMode $GatewayConfig.GatewayMode -GatewayExternalFqdn $GatewayExternalFqdn -LogonMethod $GatewayConfig.LogonMethod -UseCachedCredentials $GatewayConfig.UseCachedCredentials -BypassLocal $GatewayConfig.BypassLocal -Force
  }
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

function Add-SessionHostServer {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string[]]$SessionHostServers
  )

  foreach ($SessionHost in $SessionHostServers) {
    if (-not (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-RD-SERVER | Where-Object -Property Server -EQ $SessionHost)) {
      Write-Output "${SessionHost}: Adding RDS-RD-SERVER Server"
      Add-RDServer -ConnectionBroker $ConnectionBroker -Server $SessionHost -Role RDS-RD-SERVER
    }
  }
}

function Remove-SessionHostServer {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string[]]$SessionHostServersToKeep
  )

  Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-RD-SERVER | Where-Object -Property Server -notin $SessionHostServersToKeep | ForEach-Object {
    Write-Output ($_.Server + ": Removing RDS-RD-SERVER Server")
    Remove-RDServer -ConnectionBroker $ConnectionBroker -Server $_.Server -Role RDS-RD-SERVER -Force
  }
}

function Add-Collection {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string]$CollectionName,
    [hashtable[]]$Collection
  )

  $ExistingCollection = Get-RDSessionCollection -ConnectionBroker $ConnectionBroker | Where-Object -Property CollectionName -eq $CollectionName
  if (-not $ExistingCollection) {
    # ErrorAction set to Continue as errors are generated re GroupPolicy managed options
    Write-Output "${ConnectionBroker}: ${CollectionName}: Creating RDSessionCollection"
    New-RDSessionCollection -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -SessionHost $Collection.SessionHosts -ErrorAction Continue
  } else {
    foreach ($SessionHost in $Collection.SessionHosts) {
      $ExistingSessionHost = Get-RDSessionHost -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName | Where-Object -Property SessionHost -eq $SessionHost
      if (-not $ExistingSessionHost) {
        Write-Output "${ConnectionBroker}: ${CollectionName}: ${SessionHost}: Adding RDSessionHost"
        Add-RDSessionHost -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -SessionHost $SessionHost -ErrorAction Continue
      }
    }
  }
  Write-Output "${ConnectionBroker}: ${CollectionName}: Updating RDSessionCollection Configuration"
  $Configuration = $Collection.Configuration
  Set-RDSessionCollectionConfiguration @Configuration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName
}

function Add-Collections {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [hashtable]$Collections
  )

  foreach ($CollectionName in $Collections.Keys) {
    Add-Collection -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -Collection $Collections[$CollectionName]
  }
}

function Remove-Collections {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [hashtable]$CollectionsToKeep
  )

  $CollectionNamesToKeep = $CollectionsToKeep.Keys
  Get-RDSessionCollection -ConnectionBroker $ConnectionBroker | Where-Object -Property CollectionName -notin $CollectionNamesToKeep | ForEach-Object {
    Write-Output ("${ConnectionBroker}: " + $_.CollectionName + ": Removing RDSessionCollection")
    Remove-RDSessionCollection -ConnectionBroker $ConnectionBroker -CollectionName $_.CollectionName -Force
  }

  foreach ($CollectionName in $CollectionsToKeep.Keys) {
    $Collection = $CollectionsToKeep[$CollectionName]
    Get-RDSessionHost -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -ErrorAction SilentlyContinue | Where-Object -Property SessionHost -notin $Collection.SessionHosts | ForEach-Object {
      Write-Output ("${ConnectionBroker}: ${CollectionName}: " + $_.SessionHost + ": Removing RDSessionHost from RDSessionCollection")
      Remove-RDSessionHost -ConnectionBroker $ConnectionBroker -SessionHost $_.SessionHost -Force
    }
  }
}

function Add-RemoteApp {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string]$Alias,
    [hashtable]$Configuration
  )

  $CollectionName = $Configuration.CollectionName
  $ExistingApp = Get-RDRemoteApp -ConnectionBroker $ConnectionBroker | Where-Object -Property Alias -eq $Alias
  if (-not $ExistingApp) {
    Write-Output "${ConnectionBroker}: ${CollectionName}: ${Alias}: Creating RDRemoteApp"
    New-RDRemoteApp @Configuration -ConnectionBroker $ConnectionBroker -Alias $Alias
  } else {
    Write-Output "${ConnectionBroker}: ${CollectionName}: ${Alias}: Updating RDRemoteApp"
    Set-RDRemoteApp @Configuration -ConnectionBroker $ConnectionBroker -Alias $Alias
  }
}

function Add-RemoteApps {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [hashtable]$RemoteApps
  )

  foreach ($Alias in $RemoteApps.Keys) {
    Add-RemoteApp -ConnectionBroker $ConnectionBroker -Alias $Alias -Configuration $RemoteApps[$Alias]
  }
}

function Remove-RemoteApps {
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [hashtable]$RemoteAppsToKeep
  )

  $AliasesToKeep = $RemoteAppsToKeep.Keys
  Get-RDRemoteApp -ConnectionBroker $ConnectionBroker | Where-Object -Property Alias -notin $AliasesToKeep | ForEach-Object {
    Write-Output ("${ConnectionBroker}: " + $_.CollectionName +": " + $_.Alias + ": Removing RDRemoteApp")
    Remove-RDRemoteApp -ConnectionBroker $ConnectionBroker -CollectionName $_.CollectionName -Alias $_.Alias -Force
  }
}

$ErrorActionPreference = "Stop"
$Config = Get-Config

Install-RDSWindowsFeatures
Add-RDSessionDeployment -ConnectionBroker $Config.ConnectionBroker -SessionHosts $Config.SessionHostServers -WebAccessServer $Config.WebAccessServer
Add-RDLicensingServer -ConnectionBroker $Config.ConnectionBroker -LicensingServer $Config.LicensingServer
Add-RDGatewayServer -ConnectionBroker $Config.ConnectionBroker -GatewayServer $Config.GatewayServer -GatewayExternalFqdn $Config.GatewayExternalFqdn

# A SessionHost can only be part of 1 collection so remove it first
Remove-RemoteApps -ConnectionBroker $Config.ConnectionBroker -RemoteAppsToKeep $Config.RemoteApps
Remove-Collections -ConnectionBroker $Config.ConnectionBroker -CollectionsToKeep $Config.Collections
Add-Collections -ConnectionBroker $Config.ConnectionBroker -Collections $Config.Collections
Add-RemoteApps -ConnectionBroker $Config.ConnectionBroker -RemoteApps $Config.RemoteApps

Remove-RDWebAccessServer -ConnectionBroker $Config.ConnectionBroker -WebAccessServerToKeep $Config.WebAccessServer
Remove-RDGatewayServer -ConnectionBroker $Config.ConnectionBroker -GatewayServerToKeep $Config.GatewayServer
Remove-RDLicensingServer -ConnectionBroker $Config.ConnectionBroker -LicensingServerToKeep $Config.LicensingServer
Remove-SessionHostServer -ConnectionBroker $Config.ConnectionBroker -SessionHostServersToKeep $Config.SessionHostServers
