$GlobalConfig = @{
  "test-rds-2-b" = @{
    "ConnectionBroker" = "$env:computername.AZURE.NOMS.ROOT"
    "LicensingServer" = "AD-AZURE-RDLIC.AZURE.NOMS.ROOT"
    "GatewayServer" = "$env:computername.AZURE.NOMS.ROOT"
    "GatewayExternalFqdn" = "rdgateway2.test.hmpps-domain.service.justice.gov.uk"
    "SessionHostServers" = @("T2-JUMP2022-2.AZURE.NOMS.ROOT")
    "WebAccessServer" = "$env:computername.AZURE.NOMS.ROOT"
    "rdsOU" = "OU=RDS,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
    "svcRdsSecretsVault" = "/microsoft/AD/azure.noms.root/shared-passwords"
    "domain" = "AZURE"
    "Collections" = @{
      "Test" = @{
        "SessionHosts" = @("T2-JUMP2022-2.AZURE.NOMS.ROOT")
        "Configuration" = @{
          "CollectionDescription" = "Test Collection"
          "UserGroup" = @("Azure\Domain Users")
        }
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

function Get-SecretValue {
  param (
      [Parameter(Mandatory)]
      [string]$SecretId,
      [Parameter(Mandatory)]
      [string]$SecretKey
  )

  try {
      $secretJson = aws secretsmanager get-secret-value --secret-id $SecretId --query SecretString --output text

      if ($null -eq $secretJson -or $secretJson -eq '') {
          Write-Host "The SecretId '$SecretId' does not exist or returned no value."
          return $null
      }

      $secretObject = $secretJson | ConvertFrom-Json

      if (-not $secretObject.PSObject.Properties.Name -contains $SecretKey) {
          Write-Host "The SecretKey '$SecretKey' does not exist in the secret."
          return $null
      }

      return $secretObject.$SecretKey
  }
  catch {
      Write-Host "An error occurred while retrieving the secret: $_"
      return $null
  }
}

function Add-PermanentPSModulePath {
  param(
      [Parameter(Mandatory = $true)]
      [string]$NewPath
  )
  # IMPORTANT: This will currently only make these visible when running as ADMINISTRATOR

  # Get current Machine PSModulePath from the registry
  $regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
  $currentValue = (Get-ItemProperty -Path $regKey -Name PSModulePath).PSModulePath

  # Check if the path already exists
  if ($currentValue -split ';' -notcontains $NewPath) {
      # Add the new path
      $newValue = $currentValue + ";" + $NewPath

      # Update the registry
      Set-ItemProperty -Path $regKey -Name PSModulePath -Value $newValue

      Write-Host "Added $NewPath to system PSModulePath. Changes will take effect after restart or refreshing environment variables."
  }
  else {
      Write-Host "$NewPath is already in PSModulePath"
  }
}

function Move-ModPlatformADComputer {
  [CmdletBinding()]
  param (
      [Parameter(Mandatory = $true)][System.Management.Automation.PSCredential]$ModPlatformADCredential,
      [Parameter(Mandatory = $true)][string]$NewOU
  )

  $ErrorActionPreference = "Stop"

  # Do nothing if host not part of domain
  if (-not (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
      return $false
  }

  # Get the computer's objectGUID with a 5-minute timeout
  $timeout = [DateTime]::Now.AddMinutes(5)
  do {
      $computer = Get-ADComputer -Credential $ModPlatformADCredential -Identity $env:COMPUTERNAME -ErrorAction SilentlyContinue
      if ($computer -and $computer.objectGUID) { break }
      Start-Sleep -Seconds 5
  } until (($computer -and $computer.objectGUID) -or ([DateTime]::Now -ge $timeout))

  if (-not ($computer -and $computer.objectGUID)) {
      Write-Error "Failed to retrieve computer objectGUID within 5 minutes."
      return
  }

  # Move the computer to the new OU
  $computer.objectGUID | Move-ADObject -TargetPath $NewOU -Credential $ModPlatformADCredential

  # force group policy update
  gpupdate /force
}

$ErrorActionPreference = "Stop"

$Config = Get-Config

# Add modules permanently to PSModulePath
$ModulesPath = Join-Path $PSScriptRoot "..\..\Modules"
Add-PermanentPSModulePath -NewPath $ModulesPath
# Add to system environment (persistent)
[Environment]::SetEnvironmentVariable("PSModulePath", $env:PSModulePath + ";" + $ModulesPath, "Machine")
# Also add to current session
$env:PSModulePath = $env:PSModulePath + ";" + $ModulesPath

# Change name and Join the domain
. ../ModPlatformAD/Join-ModPlatformAD.ps1

if ($LASTEXITCODE -ne 0) {
   Exit $LASTEXITCODE
}

Import-Module ModPlatformAD -Force
$ADConfig = Get-ModPlatformADConfig
$ADAdminCredential = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig
# Move the computer to the correct OU
Move-ModPlatformADComputer -ModPlatformADCredential $ADAdminCredential -NewOU $($Config.rdsOU)

$svc_nart_password = Get-SecretValue -SecretId $($Config.svcRdsSecretsVault) -SecretKey "svc_rds" -ErrorAction SilentlyContinue

$username = "$($Config.domain)\svc_rds"
$secure_password = $svc_nart_password | ConvertTo-SecureString -AsPlainText -Force

$credentials = New-Object System.Management.Automation.PSCredential($username, $secure_password)

$commands = {
  param($Config, $localScriptRoot)
  # import module into context, this may not be needed anymore, test without later
  $ModulesRepo = Join-Path $localScriptRoot '..\..\Modules'
  $env:PSModulePath = "$ModulesRepo;$env:PSModulePath"
  Import-Module ModPlatformRemoteDesktop -Force

  Install-RDSWindowsFeatures

  # Deploy RDS components
  Add-RDSessionDeployment -ConnectionBroker $Config.ConnectionBroker -SessionHosts $Config.SessionHostServers -WebAccessServer $Config.WebAccessServer
  Add-RDLicensingServer -ConnectionBroker $Config.ConnectionBroker -LicensingServer $Config.LicensingServer
  Add-RDGatewayServer -ConnectionBroker $Config.ConnectionBroker -GatewayServer $Config.GatewayServer -GatewayExternalFqdn $Config.GatewayExternalFqdn

  # A SessionHost can only be part of 1 collection so remove it first
  Remove-RemoteApps -ConnectionBroker $Config.ConnectionBroker -RemoteAppsToKeep $Config.RemoteApps
  Remove-Collections -ConnectionBroker $Config.ConnectionBroker -CollectionsToKeep $Config.Collections
  Add-Collections -ConnectionBroker $Config.ConnectionBroker -Collections $Config.Collections
  Add-RemoteApps -ConnectionBroker $Config.ConnectionBroker -RemoteApps $Config.RemoteApps

  # Removes servers that are NOT in the $Config block
  Remove-RDWebAccessServer -ConnectionBroker $Config.ConnectionBroker -WebAccessServerToKeep $Config.WebAccessServer
  Remove-RDGatewayServer -ConnectionBroker $Config.ConnectionBroker -GatewayServerToKeep $Config.GatewayServer
  Remove-RDLicensingServer -ConnectionBroker $Config.ConnectionBroker -LicensingServerToKeep $Config.LicensingServer
  Remove-SessionHostServer -ConnectionBroker $Config.ConnectionBroker -SessionHostServersToKeep $Config.SessionHostServers
}

Invoke-Command -ComputerName localhost -ScriptBlock $commands -Credential $credentials -ArgumentList $Config, $PSScriptRoot -Authentication CredSSP

# Import-Module ModPlatformRemoteDesktop -Force
# Install-RDSWindowsFeatures
# Add-RDSessionDeployment -ConnectionBroker $Config.ConnectionBroker -SessionHosts $Config.SessionHostServers -WebAccessServer $Config.WebAccessServer
# Add-RDLicensingServer -ConnectionBroker $Config.ConnectionBroker -LicensingServer $Config.LicensingServer
# Add-RDGatewayServer -ConnectionBroker $Config.ConnectionBroker -GatewayServer $Config.GatewayServer -GatewayExternalFqdn $Config.GatewayExternalFqdn

# # A SessionHost can only be part of 1 collection so remove it first
# Remove-RemoteApps -ConnectionBroker $Config.ConnectionBroker -RemoteAppsToKeep $Config.RemoteApps
# Remove-Collections -ConnectionBroker $Config.ConnectionBroker -CollectionsToKeep $Config.Collections
# Add-Collections -ConnectionBroker $Config.ConnectionBroker -Collections $Config.Collections
# Add-RemoteApps -ConnectionBroker $Config.ConnectionBroker -RemoteApps $Config.RemoteApps

# # Removes servers that are NOT in the $Config block
# Remove-RDWebAccessServer -ConnectionBroker $Config.ConnectionBroker -WebAccessServerToKeep $Config.WebAccessServer
# Remove-RDGatewayServer -ConnectionBroker $Config.ConnectionBroker -GatewayServerToKeep $Config.GatewayServer
# Remove-RDLicensingServer -ConnectionBroker $Config.ConnectionBroker -LicensingServerToKeep $Config.LicensingServer
# Remove-SessionHostServer -ConnectionBroker $Config.ConnectionBroker -SessionHostServersToKeep $Config.SessionHostServers

. ../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1

if ($LASTEXITCODE -ne 0) {
   Exit $LASTEXITCODE
}
