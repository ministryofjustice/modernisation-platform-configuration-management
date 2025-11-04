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
      Install-WindowsFeature -Name $_ -IncludeAllSubFeature -IncludeManagementTools | Out-Null
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
    [string]$WebAccessServer,
    [switch]$WhatIf
  )

  if (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-CONNECTION-BROKER -ErrorAction SilentlyContinue) {
    if ($WhatIf.IsPresent) {
      Add-RDWebAccessServer -ConnectionBroker $ConnectionBroker -WebAccessServer $WebAccessServer -WhatIf
      Add-SessionHostServer -ConnectionBroker $ConnectionBroker -SessionHostServers $SessionHostServers -WhatIf
    } else {
      Add-RDWebAccessServer -ConnectionBroker $ConnectionBroker -WebAccessServer $WebAccessServer
      Add-SessionHostServer -ConnectionBroker $ConnectionBroker -SessionHostServers $SessionHostServers
    }
  }
  else {
    Write-Output "${ConnectionBroker}: Creating new RDSession Deployment"
    if ($WhatIf.IsPresent) {
      Write-Output "What-If: New-RDSessionDeployment -ConnectionBroker $ConnectionBroker -SessionHost $SessionHostServers -WebAccessServer $WebAccessServer"
    } else {
      New-RDSessionDeployment -ConnectionBroker $ConnectionBroker -SessionHost $SessionHostServers -WebAccessServer $WebAccessServer
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
    [string]$LicensingServer,
    [switch]$WhatIf
  )

  if (-not (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-LICENSING | Where-Object -Property Server -EQ $LicensingServer)) {
    Write-Output "${LicensingServer}: Adding RDS-LICENSING Server"
    if ($WhatIf.IsPresent) {
      Write-Output "What-If: Add-RDServer -ConnectionBroker $ConnectionBroker -Server $LicensingServer -Role RDS-LICENSING"
    } else {
      Add-RDServer -ConnectionBroker $ConnectionBroker -Server $LicensingServer -Role RDS-LICENSING
    }
  }

  if ($WhatIf.IsPresent) {
    Write-Output "What-If: skipping Get-RDLicenseConfiguration as not working undo WhatIf"
  } else {
    if ((Get-RDLicenseConfiguration -ConnectionBroker $ConnectionBroker).Mode -ne 'PerUser') {
      Write-Output "${LicensingServer}: Setting PerUser LicensingMode"
      Set-RDLicenseConfiguration -ConnectionBroker $ConnectionBroker -LicenseServer $LicensingServer -Mode PerUser -Force
    }
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
    [string]$LicensingServerToKeep,
    [switch]$WhatIf
  )

  Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-LICENSING | Where-Object -Property Server -NE $LicensingServerToKeep | ForEach-Object {
    Write-Output ($_.Server + ": Removing RDS-LICENSING Server")
    if ($WhatIf.IsPresent) {
      Write-Output ("What-If: Remove-RDServer -ConnectionBroker $ConnectionBroker -Server " + $_.Server + " -Role RDS-LICENSING -Force")
    } else {
      Remove-RDServer -ConnectionBroker $ConnectionBroker -Server $_.Server -Role RDS-LICENSING -Force
    }
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
    [string]$GatewayExternalFqdn,
    [switch]$WhatIf
  )

  if (-not (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-GATEWAY | Where-Object -Property Server -EQ $GatewayServer)) {
    Write-Output "${GatewayServer}: Adding RDS-GATEWAY Server"
    if ($WhatIf.IsPresent) {
      Write-Output "What-If: Add-RDServer -ConnectionBroker $ConnectionBroker -Server $GatewayServer -Role RDS-GATEWAY -GatewayExternalFqdn $GatewayExternalFqdn"
    } else {
      Add-RDServer -ConnectionBroker $ConnectionBroker -Server $GatewayServer -Role RDS-GATEWAY -GatewayExternalFqdn $GatewayExternalFqdn
    }
  }

  $GatewayConfig = Get-RDDeploymentGatewayConfiguration -ConnectionBroker $ConnectionBroker
  if ($GatewayConfig.GatewayExternalFQDN -ne $GatewayExternalFqdn) {
    Write-Output "${GatewayServer}: Updating FQDN: ${GatewayExternalFqdn}"
    if ($WhatIf.IsPresent) {
      Write-Output ("What-If: Set-RDDeploymentGatewayConfiguration -ConnectionBroker $ConnectionBroker -GatewayMode " + $GatewayConfig.GatewayMode + " -GatewayExternalFqdn $GatewayExternalFqdn -LogonMethod " + $GatewayConfig.LogonMethod + " -UseCachedCredentials " + $GatewayConfig.UseCachedCredentials + " -BypassLocal " + $GatewayConfig.BypassLocal + " -Force")
    } else {
      Set-RDDeploymentGatewayConfiguration -ConnectionBroker $ConnectionBroker -GatewayMode $GatewayConfig.GatewayMode -GatewayExternalFqdn $GatewayExternalFqdn -LogonMethod $GatewayConfig.LogonMethod -UseCachedCredentials $GatewayConfig.UseCachedCredentials -BypassLocal $GatewayConfig.BypassLocal -Force
    }
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
    [string]$GatewayServerToKeep,
    [switch]$WhatIf
  )

  Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-GATEWAY | Where-Object -Property Server -NE $GatewayServerToKeep | ForEach-Object {
    Write-Output ($_.Server + ": Removing RDS-GATEWAY Server")
    if ($WhatIf.IsPresent) {
      Write-Output ("What-If: Remove-RDServer -ConnectionBroker $ConnectionBroker -Server " + $_.Server + " -Role RDS-GATEWAY -Force")
    } else {
      Remove-RDServer -ConnectionBroker $ConnectionBroker -Server $_.Server -Role RDS-GATEWAY -Force
    }
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
    [string]$WebAccessServer,
    [switch]$WhatIf
  )

  if (-not (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-WEB-ACCESS | Where-Object -Property Server -EQ $WebAccessServer)) {
    Write-Output "${WebAccessServer}: Adding RDS-WEB-ACCESS Server"
    if ($WhatIf.IsPresent) {
      Write-Output "What-If: Add-RDServer -ConnectionBroker $ConnectionBroker -Server $WebAccessServer -Role RDS-WEB-ACCESS"
    } else {
      Add-RDServer -ConnectionBroker $ConnectionBroker -Server $WebAccessServer -Role RDS-WEB-ACCESS
    }
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
    [string]$WebAccessServerToKeep,
    [switch]$WhatIf
  )

  Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-WEB-ACCESS | Where-Object -Property Server -NE $WebAccessServerToKeep | ForEach-Object {
    Write-Output ($_.Server + ": Removing RDS-WEB-ACCESS Server")
    if ($WhatIf.IsPresent) {
      Write-Output ("What-If: Remove-RDServer -ConnectionBroker $ConnectionBroker -Server " + $_.Server + " -Role RDS-WEB-ACCESS -Force")
    } else {
      Remove-RDServer -ConnectionBroker $ConnectionBroker -Server $_.Server -Role RDS-WEB-ACCESS -Force
    }
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
    [string[]]$SessionHostServers,
    [switch]$WhatIf
  )

  foreach ($SessionHost in $SessionHostServers) {
    if (-not (Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-RD-SERVER | Where-Object -Property Server -EQ $SessionHost)) {
      Write-Output "${SessionHost}: Adding RDS-RD-SERVER Server"
      if ($WhatIf.IsPresent) {
        Write-Output "What-If: Add-RDServer -ConnectionBroker $ConnectionBroker -Server $SessionHost -Role RDS-RD-SERVER"
      } else {
        Add-RDServer -ConnectionBroker $ConnectionBroker -Server $SessionHost -Role RDS-RD-SERVER
      }
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
    [string[]]$SessionHostServersToKeep,
    [switch]$WhatIf
  )

  Get-RDServer -ConnectionBroker $ConnectionBroker -Role RDS-RD-SERVER | Where-Object -Property Server -notin $SessionHostServersToKeep | ForEach-Object {
    Write-Output ($_.Server + ": Removing RDS-RD-SERVER Server")
    if ($WhatIf.IsPresent) {    
      Write-Output ("What-If: Remove-RDServer -ConnectionBroker $ConnectionBroker -Server " + $_.Server + " -Role RDS-RD-SERVER -Force")
    } else {
      Remove-RDServer -ConnectionBroker $ConnectionBroker -Server $_.Server -Role RDS-RD-SERVER -Force
    }
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
    [hashtable[]]$Collection,
    [switch]$WhatIf
  )

  $ExistingCollection = Get-RDSessionCollection -ConnectionBroker $ConnectionBroker | Where-Object -Property CollectionName -eq $CollectionName
  if (-not $ExistingCollection) {
    # ErrorAction set to SilentlyContinue as errors are generated re GroupPolicy managed options and this is the only way to avoid them being seen as errors in the output
    Write-Output "${ConnectionBroker}: ${CollectionName}: Creating RDSessionCollection"
    if ($WhatIf.IsPresent) {    
      Write-Output ("What-If: New-RDSessionCollection -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -SessionHost " + $Collection.SessionHosts + " -ErrorAction SilentlyContinue")
    } else {
      New-RDSessionCollection -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -SessionHost $Collection.SessionHosts -ErrorAction SilentlyContinue
    }
  }
  else {
    foreach ($SessionHost in $Collection.SessionHosts) {
      $ExistingSessionHost = Get-RDSessionHost -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName | Where-Object -Property SessionHost -eq $SessionHost
      if (-not $ExistingSessionHost) {
        Write-Output "${ConnectionBroker}: ${CollectionName}: ${SessionHost}: Adding RDSessionHost"
        if ($WhatIf.IsPresent) {
          Write-Output "What-If: Add-RDSessionHost -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -SessionHost $SessionHost -ErrorAction SilentlyContinue"
        } else {
          Add-RDSessionHost -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -SessionHost $SessionHost -ErrorAction SilentlyContinue
        }
      }
    }
  }
  Write-Output "${ConnectionBroker}: ${CollectionName}: Updating RDSessionCollection Configuration"
  $Configuration = $Collection.Configuration
  if ($WhatIf.IsPresent) {
    Write-Output ("What-If: Set-RDSessionCollectionConfiguration " + ($Configuration | ConvertTo-Json -Compress) + " -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName")
  } else {
    Set-RDSessionCollectionConfiguration @Configuration -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName
  }
}

function Add-Collections {
  <#
.SYNOPSIS
    Add collections to the deployment if not already configured, otherwise update the configuration
#>
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [hashtable]$Collections,
    [switch]$WhatIf
  )

  foreach ($CollectionName in $Collections.Keys) {
    if ($WhatIf.IsPresent) {  
      Add-Collection -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -Collection $Collections[$CollectionName] -WhatIf
    } else {
      Add-Collection -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -Collection $Collections[$CollectionName]
    }
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
    [hashtable]$CollectionsToKeep,
    [switch]$WhatIf
  )

  $CollectionNamesToKeep = $CollectionsToKeep.Keys
  Get-RDSessionCollection -ConnectionBroker $ConnectionBroker | Where-Object -Property CollectionName -notin $CollectionNamesToKeep | ForEach-Object {
    Write-Output ("${ConnectionBroker}: " + $_.CollectionName + ": Removing RDSessionCollection")
    if ($WhatIf.IsPresent) {
      Write-Output ("What-If: Remove-RDSessionCollection -ConnectionBroker $ConnectionBroker -CollectionName " + $_.CollectionName + " -Force")
    } else {
      Remove-RDSessionCollection -ConnectionBroker $ConnectionBroker -CollectionName $_.CollectionName -Force
    }
  }

    foreach ($CollectionName in $CollectionsToKeep.Keys) {
      $Collection = $CollectionsToKeep[$CollectionName]
      Get-RDSessionHost -ConnectionBroker $ConnectionBroker -CollectionName $CollectionName -ErrorAction SilentlyContinue | Where-Object -Property SessionHost -notin $Collection.SessionHosts | ForEach-Object {
      Write-Output ("${ConnectionBroker}: ${CollectionName}: " + $_.SessionHost + ": Removing RDSessionHost from RDSessionCollection")
      if ($WhatIf.IsPresent) {
        Write-Output ("What-If: Remove-RDSessionHost -ConnectionBroker $ConnectionBroker -SessionHost " + $_.SessionHost + " -Force")
      } else {
        Remove-RDSessionHost -ConnectionBroker $ConnectionBroker -SessionHost $_.SessionHost -Force
      }
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
    [hashtable]$Configuration,
    [switch]$WhatIf
  )

  $CollectionName = $Configuration.CollectionName
  $ExistingApp = Get-RDRemoteApp -ConnectionBroker $ConnectionBroker | Where-Object -Property Alias -eq $Alias
  if (-not $ExistingApp) {
    Write-Output "${ConnectionBroker}: ${CollectionName}: ${Alias}: Creating RDRemoteApp"
    if ($WhatIf.IsPresent) {
      Write-Output ("What-If: New-RDRemoteApp " + ($Configuration  | ConvertTo-Json -Compress) + " -ConnectionBroker $ConnectionBroker -Alias $Alias")
    } else {
      New-RDRemoteApp @Configuration -ConnectionBroker $ConnectionBroker -Alias $Alias
    }
  }
  else {
    Write-Output "${ConnectionBroker}: ${CollectionName}: ${Alias}: Updating RDRemoteApp"
    if ($WhatIf.IsPresent) {
      Write-Output "What-If: Set-RDRemoteApp @Configuration -ConnectionBroker $ConnectionBroker -Alias $Alias"
    } else {
      Set-RDRemoteApp @Configuration -ConnectionBroker $ConnectionBroker -Alias $Alias
    }
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
    [hashtable]$RemoteApps,
    [switch]$WhatIf
  )
  
  foreach ($Alias in $RemoteApps.Keys) {
    if ($WhatIf.IsPresent) {
      Add-RemoteApp -ConnectionBroker $ConnectionBroker -Alias $Alias -Configuration $RemoteApps[$Alias] -WhatIf
    } else {
      Add-RemoteApp -ConnectionBroker $ConnectionBroker -Alias $Alias -Configuration $RemoteApps[$Alias]
    }
  }
}

function Add-ServerFqdnListToServerList {
  <#
  .SYNOPSIS
      Add a list of servers to the Server Manager Server List
  .DESCRIPTION
      Creates or updates the ServerList.xml file used by Server Manager
  #>
  # FIXME: move this somewhere else and add support WhatIf
  [CmdletBinding()]
  param (
    [string[]]$ServerFqdnList
  )

  # Variables for Server Manager
  $serverListPath = "$env:USERPROFILE\AppData\Roaming\Microsoft\Windows\ServerManager\ServerList.xml"
  $serverManagerPath = "$env:SystemRoot\System32\ServerManager.exe"
  
  # Ensure directory exists
  $folderPath = Split-Path -Path $serverListPath -Parent
  if (-not (Test-Path -Path $folderPath)) {
    Write-Verbose "Creating directory $folderPath"
    New-Item -Path $folderPath -ItemType Directory -Force | Out-Null
  }
  
  # Check if ServerList.xml exists
  if (-not (Test-Path -Path $serverListPath)) {
    Write-Verbose "ServerList.xml does not exist. Creating new file."
    
    # Get the local computer name
    $localHostName = [System.Net.Dns]::GetHostName()
    $fqdn = [System.Net.Dns]::GetHostByName($localHostName).HostName
    
    # Current time in ISO 8601 format
    $currentTime = [DateTime]::Now.ToString("yyyy-MM-ddTHH:mm:ss.ffffffzzz")
    
    # Create XML content with all servers
    $xmlContent = "<?xml version=""1.0"" encoding=""utf-8""?><ServerList xmlns:xsd=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" localhostName=""$fqdn"" xmlns=""urn:serverpool-schema""><ServerInfo name=""$fqdn"" status=""1"" lastUpdateTime=""$currentTime"" locale=""en-US"" />"
    
    # Add all servers from ServerFqdnList
    foreach ($server in $ServerFqdnList) {
      if ($server -ne $fqdn) {
        $xmlContent += "<ServerInfo name=""$server"" status=""2"" lastUpdateTime=""0001-01-01T00:00:00"" locale=""en-US"" />"
        Write-Output "Added server $server to new ServerList.xml"
      }
    }
    
    $xmlContent += "</ServerList>"
    
    # Save the XML content to file
    Set-Content -Path $serverListPath -Value $xmlContent
    Write-Output "Created new ServerList.xml with local server and all specified servers"
  }
  else {
    # Load the existing XML file
    $xmlContent = Get-Content -Path $serverListPath -Raw -ErrorAction SilentlyContinue
    if ($xmlContent) {
      $xmlDoc = New-Object System.Xml.XmlDocument
      
      # Test if XML content is valid
      if ($xmlContent -match "</ServerList>$") {
        $xmlDoc.LoadXml($xmlContent)
        
        # Process each server in the input list
        foreach ($server in $ServerFqdnList) {
          # Check if server already exists
          $exists = $false
          foreach ($node in $xmlDoc.ServerList.ChildNodes) {
            if ($node.name -eq $server) {
              $exists = $true
              Write-Output "Server $server already exists in ServerList.xml"
              break
            }
          }
          
          # Add the server if it doesn't exist
          if (-not $exists) {
            $serverElement = $xmlDoc.CreateElement("ServerInfo")
            $serverElement.SetAttribute("name", $server)
            $serverElement.SetAttribute("status", "2")
            $serverElement.SetAttribute("lastUpdateTime", "0001-01-01T00:00:00")
            $serverElement.SetAttribute("locale", "en-US")
            $xmlDoc.DocumentElement.AppendChild($serverElement) | Out-Null
            Write-Output "Added server $server to ServerList.xml"
          }
        }
        
        # Save the updated XML file without pretty printing
        $xmlDoc.PreserveWhitespace = $false
        
        # Use direct save first, which is simpler and less error-prone
        $saveResult = $xmlDoc.Save($serverListPath) 2>&1
        
        # If direct save fails, try with XmlTextWriter
        if ($saveResult -is [System.Management.Automation.ErrorRecord]) {
          Write-Verbose "Direct XML save failed, trying with XmlTextWriter"
          # Use System.Text.Encoding (correct namespace) instead of System.Xml.Encoding
          $xmlWriter = New-Object System.Xml.XmlTextWriter($serverListPath, [System.Text.Encoding]::UTF8) -ErrorAction SilentlyContinue
          
          # Only set formatting if the property exists
          if ($null -ne $xmlWriter -and ($xmlWriter | Get-Member -Name "Formatting" -ErrorAction SilentlyContinue)) {
            $xmlWriter.Formatting = [System.Xml.Formatting]::None
          }
          
          if ($null -ne $xmlWriter) {
            $xmlDoc.Save($xmlWriter)
            $xmlWriter.Close()
          }
          else {
            Write-Warning "Failed to create XmlTextWriter, falling back to string-based XML creation"
            # Last resort: recreate the XML content manually
            $needNewFile = $true
          }
        }
      }
      else {
        # XML is invalid, recreate the file
        Write-Warning "ServerList.xml appears to be invalid. Creating a new file."
        $needNewFile = $true
      }
    }
    else {
      # File exists but couldn't be read, recreate it
      Write-Warning "ServerList.xml exists but could not be read. Creating a new file."
      $needNewFile = $true
    }
  }
  
  # If we need to create a new file (invalid XML or couldn't read file)
  if ($needNewFile) {
    # Get the local computer name
    $localHostName = [System.Net.Dns]::GetHostName()
    $fqdn = [System.Net.Dns]::GetHostByName($localHostName).HostName
    
    # Current time in ISO 8601 format
    $currentTime = [DateTime]::Now.ToString("yyyy-MM-ddTHH:mm:ss.ffffffzzz")
    
    # Build XML content with all servers
    $xmlContent = "<?xml version=""1.0"" encoding=""utf-8""?><ServerList xmlns:xsd=""http://www.w3.org/2001/XMLSchema"" xmlns:xsi=""http://www.w3.org/2001/XMLSchema-instance"" localhostName=""$fqdn"" xmlns=""urn:serverpool-schema""><ServerInfo name=""$fqdn"" status=""1"" lastUpdateTime=""$currentTime"" locale=""en-US"" />"
    
    foreach ($server in $ServerFqdnList) {
      if ($server -ne $fqdn) {
        $xmlContent += "<ServerInfo name=""$server"" status=""2"" lastUpdateTime=""0001-01-01T00:00:00"" locale=""en-US"" />"
        Write-Output "Added server $server to rebuilt ServerList.xml"
      }
    }
    
    $xmlContent += "</ServerList>"
    
    # Save the XML content to file
    Set-Content -Path $serverListPath -Value $xmlContent
    Write-Output "Created new ServerList.xml with all specified servers"
  }
  
  # Restart Server Manager to pick up changes
  if (Get-Process ServerManager -ErrorAction SilentlyContinue) {
    Get-Process ServerManager | Stop-Process -Force
  }
  Start-Process -FilePath $serverManagerPath -WindowStyle Hidden
  
  Write-Output "Updated ServerList.xml with specified servers"
}

function Remove-RemoteApps {
  <#
.SYNOPSIS
    Remove unused remote apps from the deployment
#>
  [CmdletBinding()]
  param (
    [string]$ConnectionBroker,
    [hashtable]$RemoteAppsToKeep,
    [switch]$WhatIf
  )

  $AliasesToKeep = $RemoteAppsToKeep.Keys
  Get-RDRemoteApp -ConnectionBroker $ConnectionBroker | Where-Object -Property Alias -notin $AliasesToKeep | ForEach-Object {
    Write-Output ("${ConnectionBroker}: " + $_.CollectionName + ": " + $_.Alias + ": Removing RDRemoteApp")
    if ($WhatIf.IsPresent) {
      Write-Output ("What-If: Remove-RDRemoteApp -ConnectionBroker $ConnectionBroker -CollectionName " + $_.CollectionName + " -Alias " + $_.Alias + " -Force")
    } else {
      Remove-RDRemoteApp -ConnectionBroker $ConnectionBroker -CollectionName $_.CollectionName -Alias $_.Alias -Force
    }
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
