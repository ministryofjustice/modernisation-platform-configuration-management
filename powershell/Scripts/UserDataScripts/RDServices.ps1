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
  "test-rds-2-b" = @{
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
