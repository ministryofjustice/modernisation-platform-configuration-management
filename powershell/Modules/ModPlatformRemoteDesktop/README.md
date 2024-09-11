# Provides Remote Desktop related functions.

Module is aimed at 3 different types of EC2 instance/ASG
- RD Licensing Server EC2 instance
- RD Gateway Servers (Autoscaling Group with AWS ALB)
- RD Services (Connection Broker / Web) (Autoscaling Group with AWS ALB)

HTTPS is offloaded to AWS ALB

## RD Licensing Example

```
Install-WindowsFeature RDS-Licensing -IncludeAllSubFeature -IncludeManagementTools

Import-Module ModPlatformRemoteDesktop -Force
$CompanyInformation = Get-ModPlatformRDLicensingCompanyInformation

Add-ModPlatformRDLicensingActivation $CompanyInformation
```

## RD Gateway Example

```
$CAP = @{
  "Name" = "default"
  "AuthMethod" = 1
  "Status" = 1
  "IdleTimeout" = 120
  "SessionTimeout" = 480
  "SessionTimeoutAction" = 0
  "UserGroups" = "Domain Users@mydomain"
}
$RAP = @{
  "Name" = "default"
  "ComputerGroupType" = 2
  "UserGroups" = "Domain Users@mydomain"
}

Import-Module ModPlatformRemoteDesktop -Force

Add-ModPlatformRDGateway
Set-ModPlatformRDGatewayCAP @CAP
Set-ModPlatformRDGatewayRAP @RAP
```

# RD Services Example

```
$Config= @{
  "ConnectionBroker" = "$env:computername.$env:userdnsdomain"
  "LicensingServer" = "mylicensingserver.fqdn"
  "GatewayServer" = "$env:computername.$env:userdnsdomain"
  "GatewayExternalFqdn" = "myrdgateway.fqdn"
  "SessionHostServers" = @("mysessionhost.fqdn")
  "WebAccessServer" = "$env:computername.$env:userdnsdomain"
  "Collections" = @{
    "RDP" = @{
      "SessionHosts" = @("mysessionhost.fqdn")
      "Configuration" = @{
        "CollectionDescription" = "RemoteDesktop App Collection"
        "UserGroup" = @("mydomainuser")
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
```
