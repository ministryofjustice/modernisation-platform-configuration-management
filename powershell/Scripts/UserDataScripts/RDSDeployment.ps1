param(
    [Parameter(Mandatory=$true)]
    $Config
)

# Validation and debugging section
$logFile = "C:\Windows\Temp\RDSDeploymentConfigValidation.txt"

# Start with basic info
"RDSDeployment.ps1 started at $(Get-Date)" | Out-File -FilePath $logFile
"PowerShell Version: $($PSVersionTable.PSVersion)" | Out-File -FilePath $logFile -Append
"Config object type: $($Config.GetType().FullName)" | Out-File -FilePath $logFile -Append

# Log all top-level keys and their types
"Config keys:" | Out-File -FilePath $logFile -Append
foreach ($key in $Config.Keys) {
    $value = $Config[$key]
    $type = if ($null -eq $value) { "null" } else { $value.GetType().FullName }
    $valuePreview = if ($value -is [Array]) {
        "Array with $($value.Count) items: [" + ($value -join ", ") + "]"
    } elseif ($value -is [Hashtable] -or $value -is [System.Collections.Specialized.OrderedDictionary]) {
        "Hashtable with $($value.Count) keys: [" + ($value.Keys -join ", ") + "]"
    } else {
        $value
    }
    
    "  - $key (Type: $type): $valuePreview" | Out-File -FilePath $logFile -Append
}

Import-Module ModPlatformRemoteDesktop -Force

Install-RDSWindowsFeatures

# Deploy RDS components
Add-RDSessionDeployment -ConnectionBroker $Config.ConnectionBroker -SessionHosts $Config.SessionHostServers -WebAccessServer $Config.WebAccessServer
Add-RDLicensingServer -ConnectionBroker $Config.ConnectionBroker -LicensingServer $Config.LicensingServer
Add-RDGatewayServer -ConnectionBroker $Config.ConnectionBroker -GatewayServer $Config.GatewayServer -GatewayExternalFqdn $Config.GatewayExternalFqdn

# A SessionHost can only be part of 1 collection so remove it first
Remove-RemoteApps -ConnectionBroker $Config.ConnectionBroker -RemoteAppsToKeep $Config.RemoteApps
Remove-Collections -ConnectionBroker $Config.ConnectionBroker -CollectionsToKeep $Config.Collections
Add-Collections -ConnectionBroker $Config.ConnectionBroker -Collections $Config.Collections -ErrorAction SilentlyContinue
Add-RemoteApps -ConnectionBroker $Config.ConnectionBroker -RemoteApps $Config.RemoteApps -ErrorAction SilentlyContinue

# Removes servers that are NOT in the $Config block
Remove-RDWebAccessServer -ConnectionBroker $Config.ConnectionBroker -WebAccessServerToKeep $Config.WebAccessServer
Remove-RDGatewayServer -ConnectionBroker $Config.ConnectionBroker -GatewayServerToKeep $Config.GatewayServer
Remove-RDLicensingServer -ConnectionBroker $Config.ConnectionBroker -LicensingServerToKeep $Config.LicensingServer
Remove-SessionHostServer -ConnectionBroker $Config.ConnectionBroker -SessionHostServersToKeep $Config.SessionHostServers

# Add servers to the Server List in Server Manager
$serverFqdnList = @() + $Config.SessionHostServers + $Config.LicensingServer
Write-Host "Combined ServerFqdnList: $serverFqdnList"
Add-ServerFqdnListToServerList -ServerFqdnList $serverFqdnList
