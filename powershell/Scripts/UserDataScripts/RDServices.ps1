<#
.SYNOPSIS
    Configures Remote Desktop Services deployment.

.DESCRIPTION
    This script automates the setup and configuration of Remote Desktop Services, including connection brokers, gateways, and session hosts.

    You can run the script manually but only by running as Admin and logged in as a domain user.

.PARAMETER RunManually
    Use this switch when running the script manually instead of via AWS userdata.
    Shows important prerequisites and asks for confirmation before proceeding.

    If this switch isn't select then the svc_rds user is used and this gets the password from Secrets Manager.

.EXAMPLE
    .\RDServices.ps1 -RunManually

    Runs the script, especially the RDS deployment component, using your domain credentials.

.NOTES
    Requires administrative privileges & the machine must already be joined to the domain.
#>
[CmdletBinding()]
param(
  [Parameter(HelpMessage = "Run this script manually as a different user to deploy the RDS components")]
  [switch]$RunManually
)

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
      "Jumpserver" = @{
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
          "UserGroup"             = @("HMPP\PROD_CAFM_admins")
        }
      }
      "Jumpserver" = @{
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
          "UserGroup"             = @("HMPP\PROD_CAFM_admins")
        }
      }
      "Jumpserver" = @{
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

# move the RDS server to the RDServices OU
Import-Module ModPlatformAD -Force
. ../ModPlatformAD/Move-ModPlatformADComputer.ps1

# Path to the deployment scripts
$deploymentScriptPath = Join-Path $PSScriptRoot "RDSDeployment.ps1"

# Display a message if running manually
if ($RunManually) {
  Write-Host "Running in manual mode. Please ensure the following conditions are met:" -ForegroundColor Yellow
  Write-Host " - You are running this script as an Administrator" -ForegroundColor Yellow
  Write-Host " - Your user is Local Administrator on all RDS component servers, inc. all Session Host(s)" -ForegroundColor Yellow
  Write-Host " - The machine must already be joined to the domain" -ForegroundColor Yellow
  Write-Host " - You must use your domain account to run this script" -ForegroundColor Yellow
  Write-Host ""

  $continue = Read-Host "Continue? (y/n)"
  if ($continue -notmatch "^[yY]") {
    Write-Host "Exiting script." -ForegroundColor Red
    exit
  }
  else {
    # Just dot-source and run the script in the current context
    # This runs with the current user's credentials
    . $deploymentScriptPath -Config $Config
  }
}
else {
  $Config = Get-Config
  if ($null -eq $Config.svcRdsSecretsVault) {
    Write-Host "No svcRdsSecretsVault found in config. Exiting." -ForegroundColor Red
    exit 1
  }

  $svc_rds_password = Get-SecretValue -SecretId $($Config.svcRdsSecretsVault) -SecretKey "svc_rds" -ErrorAction SilentlyContinue

  $username = "$($Config.domain)\svc_rds"
  $secure_password = $svc_rds_password | ConvertTo-SecureString -AsPlainText -Force

  $credentials = New-Object System.Management.Automation.PSCredential($username, $secure_password)

  Invoke-Command -ComputerName localhost -FilePath $deploymentScriptPath -Credential $credentials -ArgumentList $Config -Authentication CredSSP -Verbose
}

. ../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1

if ($LASTEXITCODE -ne 0) {
  Exit $LASTEXITCODE
}
