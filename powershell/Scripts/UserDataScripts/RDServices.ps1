$GlobalConfig = @{
  "test-rds-2-a" = @{
    "ConnectionBroker" = "$env:computername.AZURE.NOMS.ROOT"
    "LicensingServer" = "AD-AZURE-RDLIC.AZURE.NOMS.ROOT"
    "GatewayServer" = "$env:computername.AZURE.NOMS.ROOT"
    "GatewayExternalFqdn" = "rdgateway2.test.hmpps-domain.service.justice.gov.uk"
    "SessionHostServers" = @("EC2AMAZ-3SQ0F6I.AZURE.NOMS.ROOT")
    "WebAccessServer" = "$env:computername.AZURE.NOMS.ROOT"
    "Collections" = @{
      "CAFM-RDP" = @{
        "SessionHosts" = @("EC2AMAZ-3SQ0F6I.AZURE.NOMS.ROOT")
        "Configuration" = @{
          "CollectionDescription" = "PlanetFM RemoteDesktop App Collection"
          "UserGroup" = @("Azure\Domain Users")
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
  "pp-rds-1-a" = @{
    "ConnectionBroker" = "$env:computername.AZURE.HMPP.ROOT"
    "LicensingServer" = "AD-HMPP-RDLIC.AZURE.HMPP.ROOT"
    "GatewayServer" = "$env:computername.AZURE.HMPP.ROOT"
    "GatewayExternalFqdn" = "rdgateway1.preproduction.hmpps-domain.service.justice.gov.uk"
    "SessionHostServers" = @("PP-CAFM-A-11-A.AZURE.HMPP.ROOT")
    "WebAccessServer" = "$env:computername.AZURE.HMPP.ROOT"
    "Collections" = @{
      "CAFM-RDP PreProd" = @{
        "SessionHosts" = @("PP-CAFM-A-11-A.AZURE.HMPP.ROOT")
        "Configuration" = @{
          "CollectionDescription" = "CAFM-RDP PreProd Modernisation Platform"
          "UserGroup" = @("HMPP\PROD_CAFM_admins")
        }
      }
    }
    "RemoteApps" = @{
      "calc" = @{
        "CollectionName" = "CAFM-RDP PreProd"
        "DisplayName" = "Calculator"
        "FilePath" = 'C:\Windows\system32\calc.exe'
      }
      "PlanetEnterprise" = @{
        "CollectionName" = "CAFM-RDP PreProd"
        "DisplayName" = "Qube Planet"
        "FilePath" = 'C:\Program Files (x86)\Qube\Planet FM Enterprise\Programs\PlanetEnterprise.exe'
      }
    }
  }
  "pd-rds-1-a" = @{
    "ConnectionBroker" = "$env:computername.AZURE.HMPP.ROOT"
    "LicensingServer" = "AD-HMPP-RDLIC.AZURE.HMPP.ROOT"
    "GatewayServer" = "$env:computername.AZURE.HMPP.ROOT"
    "GatewayExternalFqdn" = "rdgateway1.hmpps-domain.service.justice.gov.uk"
    "SessionHostServers" = @("PD-CAFM-A-11-A.AZURE.HMPP.ROOT", "PD-CAFM-A-12-B.AZURE.HMPP.ROOT", "PD-CAFM-A-13-A.AZURE.HMPP.ROOT")
    "WebAccessServer" = "$env:computername.AZURE.HMPP.ROOT"
    "Collections" = @{
      "CAFM-RDP" = @{
        "SessionHosts" = @("PD-CAFM-A-11-A.AZURE.HMPP.ROOT", "PD-CAFM-A-12-B.AZURE.HMPP.ROOT", "PD-CAFM-A-13-A.AZURE.HMPP.ROOT")
        "Configuration" = @{
          "CollectionDescription" = "PlanetFM RemoteDesktop App Collection"
          "UserGroup" = @("HMPP\PROD_CAFM_admins")
        }
      }
    }
    "RemoteApps" = @{
      "calc" = @{
        "CollectionName" = "CAFM-RDP"
        "DisplayName" = "Calculator"
        "FilePath" = 'C:\Windows\system32\calc.exe'
      }
      "PlanetEnterprise" = @{
        "CollectionName" = "CAFM-RDP"
        "DisplayName" = "Qube Planet"
        "FilePath" = 'C:\Program Files (x86)\Qube\Planet FM Enterprise\Programs\PlanetEnterprise.exe'
      }
    }
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

$ErrorActionPreference = "Stop"

. ../ModPlatformAD/Join-ModPlatformAD.ps1 -NewHostname "keep-existing"

if ($LASTEXITCODE -ne 0) {
   Exit $LASTEXITCODE
}

Import-Module ModPlatformRemoteDesktop -Force

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

. ../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1

if ($LASTEXITCODE -ne 0) {
   Exit $LASTEXITCODE
}
