<#
.SYNOPSIS
    Configure Remote Desktop Services

.DESCRIPTION
    By default derives the configuration from the EC2 Name tag
    EC2 requires permissions to get tags and the aws cli.

.EXAMPLE
    Add-ModPlatformRDServices.ps1
#>

$GlobalConfig = @{
  "test-rds-2-b" = @{
    "ConnectionBroker"    = "$env:computername.AZURE.NOMS.ROOT"
    "LicensingServer"     = "AD-AZURE-RDLIC.AZURE.NOMS.ROOT"
    "GatewayServer"       = "$env:computername.AZURE.NOMS.ROOT"
    "GatewayExternalFqdn" = "rdgateway1.test.hmpps-domain.service.justice.gov.uk"
    "SessionHostServers"  = @("T1-JUMP2022-1.AZURE.NOMS.ROOT")
    "WebAccessServer"     = "$env:computername.AZURE.NOMS.ROOT"
    "svcRdsSecretsVault"  = "/microsoft/AD/azure.noms.root/shared-passwords"
    "domain"              = "AZURE"
    "Collections"         = @{
      "t1-jump2022-1" = @{
        "SessionHosts"  = @("T1-JUMP2022-1.AZURE.NOMS.ROOT")
        "Configuration" = @{
          "CollectionDescription" = "Connect to Jumpserver T1-JUMP2022-1"
          "UserGroup"             = @("Azure\HmppsJump2022")
        }
      }
    }
  }
  "pp-rds-1-a"   = @{
    "ConnectionBroker"    = "$env:computername.AZURE.HMPP.ROOT"
    "LicensingServer"     = "AD-HMPP-RDLIC.AZURE.HMPP.ROOT"
    "GatewayServer"       = "$env:computername.AZURE.HMPP.ROOT"
    "GatewayExternalFqdn" = "rdgateway1.preproduction.hmpps-domain.service.justice.gov.uk"
    "SessionHostServers"  = @("PP-CAFM-A-11-A.AZURE.HMPP.ROOT", "PP-JUMP2022-1.AZURE.HMPP.ROOT")
    "WebAccessServer"     = "$env:computername.AZURE.HMPP.ROOT"
    "svcRdsSecretsVault"  = "/microsoft/AD/azure.hmpp.root/shared-passwords"
    "domain"              = "HMPP"
    "Collections"         = @{
      "CAFM-RDP PreProd" = @{
        "SessionHosts"  = @("PP-CAFM-A-11-A.AZURE.HMPP.ROOT")
        "Configuration" = @{
          "CollectionDescription" = "CAFM-RDP PreProd Modernisation Platform"
          "UserGroup"             = @("HMPP\PROD_CAFM_SQL_USERS")
        }
      }
      "pp-jump2022-1" = @{
        "SessionHosts"  = @("PP-JUMP2022-1.AZURE.HMPP.ROOT")
        "Configuration" = @{
          "CollectionDescription" = "Connect to Jumpserver PP-JUMP2022-1"
          "UserGroup"             = @("HMPP\HmppsJump2022")
        }
      }
    }
    "RemoteApps"          = @{
      "calc"             = @{
        "CollectionName" = "CAFM-RDP PreProd"
        "DisplayName"    = "Calculator"
        "FilePath"       = 'C:\Windows\system32\calc.exe'
      }
      "PlanetEnterprise" = @{
        "CollectionName" = "CAFM-RDP PreProd"
        "DisplayName"    = "Qube Planet"
        "FilePath"       = 'C:\Program Files (x86)\Qube\Planet FM Enterprise\Programs\PlanetEnterprise.exe'
      }
    }
  }
  "pd-rds-1-a"   = @{
    "ConnectionBroker"    = "$env:computername.AZURE.HMPP.ROOT"
    "LicensingServer"     = "AD-HMPP-RDLIC.AZURE.HMPP.ROOT"
    "GatewayServer"       = "$env:computername.AZURE.HMPP.ROOT"
    "GatewayExternalFqdn" = "rdgateway1.hmpps-domain.service.justice.gov.uk"
    "SessionHostServers"  = @("PD-CAFM-A-11-A.AZURE.HMPP.ROOT", "PD-CAFM-A-12-B.AZURE.HMPP.ROOT", "PD-CAFM-A-13-A.AZURE.HMPP.ROOT", "PD-JUMP2022-1.AZURE.HMPP.ROOT")
    "WebAccessServer"     = "$env:computername.AZURE.HMPP.ROOT"
    "svcRdsSecretsVault"  = "/microsoft/AD/azure.hmpp.root/shared-passwords"
    "domain"              = "HMPP"
    "Collections"         = @{
      "CAFM-RDP" = @{
        "SessionHosts"  = @("PD-CAFM-A-11-A.AZURE.HMPP.ROOT", "PD-CAFM-A-12-B.AZURE.HMPP.ROOT", "PD-CAFM-A-13-A.AZURE.HMPP.ROOT")
        "Configuration" = @{
          "CollectionDescription" = "PlanetFM RemoteDesktop App Collection"
          "UserGroup"             = @("HMPP\PROD_CAFM_SQL_USERS")
        }
      }
      "pd-jump2022-1" = @{
        "SessionHosts" = @("PD-JUMP2022-1.AZURE.HMPP.ROOT")
        "Configuration" = @{
          "CollectionDescription" = "Connect to Jumpserver PD-JUMP2022-1"
          "UserGroup"             = @("HMPP\HmppsJump2022")
        }
      }
    }
    "RemoteApps"          = @{
      "calc"             = @{
        "CollectionName" = "CAFM-RDP"
        "DisplayName"    = "Calculator"
        "FilePath"       = 'C:\Windows\system32\calc.exe'
      }
      "PlanetEnterprise" = @{
        "CollectionName" = "CAFM-RDP"
        "DisplayName"    = "Qube Planet"
        "FilePath"       = 'C:\Program Files (x86)\Qube\Planet FM Enterprise\Programs\PlanetEnterprise.exe'
      }
    }
  }
}

function Get-Config {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = 3600 } -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token } -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $NameTag = ($Tags.Tags | Where-Object { $_.Key -eq "Name" }).Value

  if (-not $GlobalConfig.Contains($NameTag)) {
    Write-Error "Unexpected Name tag value $NameTag"
  }
  Return $GlobalConfig[$NameTag]
}

$Config = Get-Config
Import-Module ModPlatformRemoteDesktop -Force

# Install all RDS features
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
Write-Output "Combined ServerFqdnList: $serverFqdnList"
Add-ServerFqdnListToServerList -ServerFqdnList $serverFqdnList
