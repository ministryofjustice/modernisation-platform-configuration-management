function Install-RDSWindowsFeatures {
  <#
.SYNOPSIS
    Install RDS Windows Features
#>
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
  <#
.SYNOPSIS
    Create or Update an RDSession Deployment
#>
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string[]]$SessionHostServers,
    [string]$WebAccessServer
  )
  if (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-CONNECTION-BROKER -ErrorAction SilentlyContinue) {
    Add-RDWebAccessServer -ConnectionBroker $ConnectionBroker -WebAccessServer $WebAccessServer
    Add-SessionHostServer -ConnectionBroker $ConnectionBroker -SessionHostServers $SessionHostServers
  }
  else {
    Write-Output "${ConnectionBroker}: Creating new RDSession Deployment"
    New-RDSessionDeployment -ConnectionBroker $ConnectionBroker -SessionHost $SessionHostServers -WebAccessServer $WebAccessServer
  }
}

function Add-RDLicensingServer {
  <#
.SYNOPSIS
    Add a new RD Licensing Server to the deployment if it is not already configured
#>
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
  <#
.SYNOPSIS
    Remove unused RD Licensing Servers from the deployment
#>
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
  <#
.SYNOPSIS
    Add or update an RDGatewayServer to the deployment
#>
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
  <#
.SYNOPSIS
    Remove unused RDGatewayServer from the deployment
#>
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
  <#
.SYNOPSIS
    Add RDWebAccess server to the deployment if it is not already configured
#>
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
  <#
.SYNOPSIS
    Remove unused RDWebAccess server from the deployment
#>
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
  <#
.SYNOPSIS
    Add session host servers to the deployment if not already configured
#>
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
  <#
.SYNOPSIS
    Remove unused session host servers from the deployment
#>
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
  <#
.SYNOPSIS
    Add a collection to the deployment if not already configured, otherwise update the configuration
#>
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [string]$CollectionName,
    [hashtable[]]$Collection
  )

  $ExistingCollection = Get-RDSessionCollection -ConnectionBroker $ConnectionBroker | Where-Object -Property CollectionName -eq $CollectionName
  if (-not $ExistingCollection) {
    # ErrorAction set to SilentlyContinue as errors are generated re GroupPolicy managed options and this is the only way to avoid them being seen as errors in the output
    Write-Output "${ConnectionBroker}: ${CollectionName}: Creating RDSessionCollection"
    New-RDSessionCollection -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -SessionHost $Collection.SessionHosts -ErrorAction SilentlyContinue
  }
  else {
    foreach ($SessionHost in $Collection.SessionHosts) {
      $ExistingSessionHost = Get-RDSessionHost -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName | Where-Object -Property SessionHost -eq $SessionHost
      if (-not $ExistingSessionHost) {
        Write-Output "${ConnectionBroker}: ${CollectionName}: ${SessionHost}: Adding RDSessionHost"
        Add-RDSessionHost -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -SessionHost $SessionHost -ErrorAction SilentlyContinue
      }
    }
  }
  Write-Output "${ConnectionBroker}: ${CollectionName}: Updating RDSessionCollection Configuration"
  $Configuration = $Collection.Configuration
  Set-RDSessionCollectionConfiguration @Configuration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName
}

function Add-Collections {
  <#
.SYNOPSIS
    Add collections to the deployment if not already configured, otherwise update the configuration
#>
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
  <#
.SYNOPSIS
    Remove any unused collections from the deployment
#>
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
  <#
.SYNOPSIS
    Add a remote app to the deployment if not already configured, otherwise update the configuration
#>
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
  }
  else {
    Write-Output "${ConnectionBroker}: ${CollectionName}: ${Alias}: Updating RDRemoteApp"
    Set-RDRemoteApp @Configuration -ConnectionBroker $ConnectionBroker -Alias $Alias
  }
}

function Add-ServerFqdnListToServerList {
  <#
.SYNOPSIS
    Add a list of servers to the Server Manager Server List
#>
  [CmdletBinding()]
  param (
    [string[]]$ServerFqdnList

  )
  # Stop the ServerManager process
  if (Get-Process ServerManager) {
    Get-Process ServerManager | Stop-Process -Force
  }
  else {
    Write-Output "ServerManager process not running, just continue"
  }
  # Get the ServerList.xml file
  $file = Get-Item "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\ServerManager\ServerList.xml"
  # Backup the ServerList.xml file
  Copy-Item -Path $file -Destination $file-backup -Force
  # Get the content of the ServerList.xml file in XML format
  $xml = [xml](Get-Content $file)
  # Clone an existing managed server element to a new XML element
  foreach ($server in $ServerFqdnList) {
    # Check if server already exists in the XML
    $serverExists = $false
    foreach ($existingServer in $xml.ServerList.ServerInfo) {
      if ($existingServer.Name -eq $server) {
        $serverExists = $true
        break
      }
    }  
    # Only add the server if it doesn't already exist
    if (-not $serverExists) {
      $newserver = @($xml.ServerList.ServerInfo)[0].clone()
      $newserver.Name = $server
      $newserver.lastUpdateTime = "01/01/0001 00:00:00"
      $newserver.status = "2"
      $xml.ServerList.AppendChild($newserver)
      Write-Output "Added server $server to XML"
    }
    else {
      Write-Output "Server $server already exists in XML, skipping"
    }

  }
  # Save the new XML content to the ServerList.xml file
  $xml.Save($file.FullName)
  # Start the ServerManager process
  Start-Process -FilePath $env:SystemRoot\System32\ServerManager.exe -WindowStyle Hidden
}

function Remove-RemoteApps {
  <#
.SYNOPSIS
    Remove unused remote apps from the deployment
#>
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [hashtable]$RemoteAppsToKeep
  )

  $AliasesToKeep = $RemoteAppsToKeep.Keys
  Get-RDRemoteApp -ConnectionBroker $ConnectionBroker | Where-Object -Property Alias -notin $AliasesToKeep | ForEach-Object {
    Write-Output ("${ConnectionBroker}: " + $_.CollectionName + ": " + $_.Alias + ": Removing RDRemoteApp")
    Remove-RDRemoteApp -ConnectionBroker $ConnectionBroker -CollectionName $_.CollectionName -Alias $_.Alias -Force
  }
}

Export-ModuleMember -Function Install-RDSWindowsFeatures
Export-ModuleMember -Function Add-RDSessionDeployment
Export-ModuleMember -Function Add-RDLicensingServer
Export-ModuleMember -Function Remove-RDLicensingServer
Export-ModuleMember -Function Add-RDGatewayServer
Export-ModuleMember -Function Remove-RDGatewayServer
Export-ModuleMember -Function Add-RDWebAccessServer
Export-ModuleMember -Function Remove-RDWebAccessServer
Export-ModuleMember -Function Add-SessionHostServer
Export-ModuleMember -Function Remove-SessionHostServer
Export-ModuleMember -Function Add-Collection
Export-ModuleMember -Function Add-Collections
Export-ModuleMember -Function Remove-Collections
Export-ModuleMember -Function Add-RemoteApp
Export-ModuleMember -Function Add-RemoteApps
Export-ModuleMember -Function Remove-RemoteApps
Export-ModuleMember -Function Add-ServerFqdnListToServerList
