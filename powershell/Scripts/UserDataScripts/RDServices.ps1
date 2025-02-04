$GlobalConfig = @{
  "test-rds-2-a" = @{
    "ConnectionBroker"    = "$env:computername.AZURE.NOMS.ROOT"
    "LicensingServer"     = "AD-AZURE-RDLIC.AZURE.NOMS.ROOT"
    "GatewayServer"       = "$env:computername.AZURE.NOMS.ROOT"
    "GatewayExternalFqdn" = "rdgateway2.test.hmpps-domain.service.justice.gov.uk"
    "SessionHostServers"  = @("T2-JUMP2022-2.AZURE.NOMS.ROOT")
    "WebAccessServer"     = "$env:computername.AZURE.NOMS.ROOT"
    "RDSComputersOU"      = "OU=RDS,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
    "Domain"              = "AZURE"  
    "Collections"         = @{}
    "RemoteApps"          = @{}
  }
  "pp-rds-1-a"   = @{
    "ConnectionBroker"    = "$env:computername.AZURE.HMPP.ROOT"
    "LicensingServer"     = "AD-HMPP-RDLIC.AZURE.HMPP.ROOT"
    "GatewayServer"       = "$env:computername.AZURE.HMPP.ROOT"
    "GatewayExternalFqdn" = "rdgateway1.preproduction.hmpps-domain.service.justice.gov.uk"
    "SessionHostServers"  = @("PP-CAFM-A-11-A.AZURE.HMPP.ROOT")
    "WebAccessServer"     = "$env:computername.AZURE.HMPP.ROOT"
    "Collections"         = @{
      "CAFM-RDP PreProd" = @{
        "SessionHosts"  = @("PP-CAFM-A-11-A.AZURE.HMPP.ROOT")
        "Configuration" = @{
          "CollectionDescription" = "CAFM-RDP PreProd Modernisation Platform"
          "UserGroup"             = @("HMPP\PROD_CAFM_admins")
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
    "SessionHostServers"  = @("PD-CAFM-A-11-A.AZURE.HMPP.ROOT", "PD-CAFM-A-12-B.AZURE.HMPP.ROOT", "PD-CAFM-A-13-A.AZURE.HMPP.ROOT")
    "WebAccessServer"     = "$env:computername.AZURE.HMPP.ROOT"
    "Collections"         = @{
      "CAFM-RDP" = @{
        "SessionHosts"  = @("PD-CAFM-A-11-A.AZURE.HMPP.ROOT", "PD-CAFM-A-12-B.AZURE.HMPP.ROOT", "PD-CAFM-A-13-A.AZURE.HMPP.ROOT")
        "Configuration" = @{
          "CollectionDescription" = "PlanetFM RemoteDesktop App Collection"
          "UserGroup"             = @("HMPP\PROD_CAFM_admins")
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
    try {
      $computer = Get-ADComputer -Credential $ModPlatformADCredential -Filter "Name -eq '$env:COMPUTERNAME'" -ErrorAction Stop
      if ($computer -and $computer.objectGUID) { break }
    }
    catch {
      Write-Verbose "Get-ADComputer failed: $_"
    }
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

. $PSScriptRoot/../ModPlatformAD/Join-ModPlatformAD.ps1 -NewHostname "keep-existing"

if ($LASTEXITCODE -ne 0) {
  Exit $LASTEXITCODE
}

Import-Module ModPlatformAD -Force
$ADConfig = Get-ModPlatformADConfig
# Get the AD Admin credentials
$ADAdminCredential = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig

# Get Config values
$Config = Get-Config
# Move the computer to the correct OU
Move-ModPlatformADComputer -ModPlatformADCredential $ADAdminCredential -NewOU $($Config.RDSComputersOU)

# do the equivalent for gpupdate /force in powershell
Install-WindowsFeature GPMC
Invoke-GPUpdate -Force

Import-Module ModPlatformRemoteDesktop -Force

Install-RDSWindowsFeatures

# foreach ($server in $Config.SessionHostServers) {
#   Set-Item WSMan:\localhost\Client\TrustedHosts -Value $server -Force
# }

Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
Enable-WSManCredSSP -Role Client -DelegateComputer "*" -Force

# FIXME: -> this SecretId needs to be changeable 
$svc_nart_password = Get-SecretValue -SecretId "/microsoft/AD/azure.noms.root/shared-passwords" -SecretKey "svc_rds" -ErrorAction SilentlyContinue

$username = "$($Config.Domain)\svc_rds"
$secure_password = $svc_nart_password | ConvertTo-SecureString -AsPlainText -Force

$creds = New-Object System.Management.Automation.PSCredential($username, $secure_password)

$commands = {
  param($Config)
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
}

Invoke-Command -ComputerName localhost -ScriptBlock $commands -Credential $creds -ArgumentList $Config

. ../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1

if ($LASTEXITCODE -ne 0) {
  Exit $LASTEXITCODE
}
