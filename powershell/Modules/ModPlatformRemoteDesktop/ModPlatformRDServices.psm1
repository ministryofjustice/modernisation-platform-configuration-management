function Clear-PendingFileRenameOperations {
  <#
.SYNOPSIS
    Clears pending filename operations so pre-install checks work
#>
  $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending"
  $regKey = "PendingFileRenameOperations"

  if (Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction SilentlyContinue) {
    try {
      Remove-ItemProperty -Path $regPath -Name $regKey -Force -ErrorAction Stop
      Write-Host "Successfully removed $regKey from the registry."
    }
    catch {
      Write-Warning "Failed to remove $regKey. Error: $_"
    }
  }
  else {
    Write-Host "$regKey does not exist in the registry. No action needed."
  }
}

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
      Write-Output "Clearing rename operations ahead of installing $_ Feature"
      Write-Output "Installing $_ Feature"
      Install-WindowsFeature -Name $_ -IncludeAllSubFeature -IncludeManagementTools -Restart
    }
  }
}

function Test-PSRemotingConnection {
  param(
    [string]$ServerName,
    [int]$MaxAttempts = 5,
    [int]$WaitSeconds = 30
  )
  
  for ($i = 1; $i -le $MaxAttempts; $i++) {
    Write-Verbose "Attempt $i of $MaxAttempts to verify PS Remoting to $ServerName"
      
    try {
      # Test basic connectivity
      Test-WSMan -ComputerName $ServerName -ErrorAction Stop

      # Try to establish a session and run a simple command
      # FIXME: Remove this as it will only work with certain credentials and is too over-the-top
      # $session = New-PSSession -ComputerName $ServerName -ErrorAction Stop
      # Invoke-Command -Session $session -ScriptBlock { Get-Service TermService } -ErrorAction Stop
      # Remove-PSSession $session

      Write-Verbose "PowerShell remoting connection to $ServerName successful!"
      return $true
    }
    catch {
      Write-Verbose "Attempt $i failed. Waiting $WaitSeconds seconds before retry..."
      Start-Sleep -Seconds $WaitSeconds
    }
  }
  
  Write-Verbose "Failed to establish PowerShell remoting to $ServerName after $MaxAttempts attempts"
  return $false
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
    foreach ($server in $SessionHostServers) {
      if (Test-PSRemotingConnection -ServerName $server -MaxAttempts 5 -WaitSeconds 30 -Verbose) {
        Write-Output "${ConnectionBroker}: Creating new RDSession Deployment"
        New-RDSessionDeployment -ConnectionBroker $ConnectionBroker -SessionHost $server -WebAccessServer $WebAccessServer
        Add-RDServer -Server $server -Role "RDS-RD-SERVER" -ConnectionBroker $ConnectionBroker
      }
      else {
        Write-Output "PowerShell Remoting validation failed for $server. "
        return
      }
    }
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
    # ErrorAction set to Continue as errors are generated re GroupPolicy managed options
    Write-Output "${ConnectionBroker}: ${CollectionName}: Creating RDSessionCollection"
    New-RDSessionCollection -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -SessionHost $Collection.SessionHosts -ErrorAction Continue
  }
  else {
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

function Add-RemoteApps {
  <#
.SYNOPSIS
    Add remote apps to the deployment if not already configured, otherwise update the configuration
#>
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
