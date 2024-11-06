$GlobalConfig = @{
    "all" = @{
         "BOEWindowsClientS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
         "BOEWindowsClientS3Folder" = "hmpps/onr"
         "BOEWindowsClientS3File" = "51048121.ZIP"
         "Oracle11g64bitClientS3File" = "V20609-01.zip"
         "Oracle19c64bitClientS3File" = "WINDOWS.X64_193000_client.zip" # Oracle 19c client SW, install 1st"
         "ORACLE_19C_HOME"       = "E:\app\oracle\product\19.0.0\client_1"
         "ORACLE_11G_HOME"       = "E:\app\oracle\product\11.2.0\client_1"
         "ORACLE_BASE"           = "E:\app\oracle"
         "RegistryPath" = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon"
         "LegalNoticeCaption" = "IMPORTANT"
         "LegalNoticeText" = "This system is restricted to authorized users only. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information"
    }
    "oasys-national-reporting-dev" = @{
      "OnrShortcuts" = @{
      }
    }
    "oasys-national-reporting-test"  = @{
      "serviceUser"     = "svc_nart"
      "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
      "domain"          = "AZURE"
      "OnrShortcuts" = @{
        "Onr CmcApp" = "http://t2-onr-web-1-a.oasys-national-reporting.hmpps-test.modernisation-platform.service.justice.gov.uk:7777/CmcApp"
      }
    }
    "oasys-national-reporting-preproduction" = @{
        "serviceUser"     = "svc_nart"
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT"
        "domain"          = "HMPP"
        "OnrShortcuts" = @{
      }
    }
    "oasys-national-reporting-production" = @{
        "serviceUser"     = "svc_nart"
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT"
        "domain"          = "HMPP"
        "OnrShortcuts" = @{
      }
    }
 }

 $tempPath = ([System.IO.Path]::GetTempPath())

 $ConfigurationManagementRepo = "$tempPath\modernisation-platform-configuration-management"
 $ErrorActionPreference = "Stop"
 $WorkingDirectory = "C:\Software"
 $AppDirectory = "C:\App"

 New-Item -ItemType Directory -Path $WorkingDirectory -Force
 New-Item -ItemType Directory -Path $AppDirectory -Force

# {{{ functions

function Get-Config {
    $tokenParams = @{
        TimeoutSec = 10
        Headers    = @{"X-aws-ec2-metadata-token-ttl-seconds" = 3600}
        Method     = 'PUT'
        Uri        = 'http://169.254.169.254/latest/api/token'
    }
    $Token = Invoke-RestMethod @tokenParams

    $instanceIdParams = @{
        TimeoutSec = 10
        Headers    = @{"X-aws-ec2-metadata-token" = $Token}
        Method     = 'GET'
        Uri        = 'http://169.254.169.254/latest/meta-data/instance-id'
    }
    $InstanceId = Invoke-RestMethod @instanceIdParams

    $awsParams = @(
        'ec2',
        'describe-tags',
        '--filters',
        "Name=resource-id,Values=$InstanceId"
    )

    $TagsRaw = & aws @awsParams

    $Tags = $TagsRaw | ConvertFrom-Json
    $EnvironmentNameTag = ($Tags.Tags | Where-Object { $_.Key -eq "environment-name" }).Value

    if (-not $GlobalConfig.Contains($EnvironmentNameTag)) {
        Write-Error "Unexpected environment-name tag value $EnvironmentNameTag"
    }

    Return $GlobalConfig.all + $GlobalConfig[$EnvironmentNameTag]
}

function Get-Installer {
    param (
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $s3Params = @{
        BucketName = $Config.WindowsClientS3Bucket
        Key        = ($Config.WindowsClientS3Folder + "/" + $Key)
        File       = $Destination
        Verbose    = $true
    }

    Read-S3Object @s3Params
}

 function Add-BOEWindowsClient {
   [CmdletBinding()]
   param (
     [hashtable]$Config
   )

   $ErrorActionPreference = "Stop"
   if (Test-Path (([System.IO.Path]::GetTempPath()) + "\BOE\setup.exe")) {
     Write-Output "BOE Windows Client already installed"
   } else {
     Write-Output "Add BOE Windows Client"
     Set-Location -Path ([System.IO.Path]::GetTempPath())
     Read-S3Object -BucketName $Config.BOEWindowsClientS3Bucket -Key ($Config.BOEWindowsClientS3Folder + "/" + $Config.BOEWindowsClientS3File) -File (".\" + $Config.BOEWindowsClientS3File) -Verbose | Out-Null

     # Extract BOE Client Installer - there is no installer for this application
     Expand-Archive -Path (".\" + $Config.BOEWindowsClientS3File) -DestinationPath  (([System.IO.Path]::GetTempPath()) + "\BOE") -Force | Out-Null

     # Install BOE Windows Client
     Start-Process -FilePath (([System.IO.Path]::GetTempPath()) + "\BOE\setup.exe") -ArgumentList "-r", "$ConfigurationManagementRepo\powershell\Configs\OnrClientResponse.ini" -Wait -NoNewWindow

     # Create a desktop shortcut for BOE Client Tools
    $WScriptShell = New-Object -ComObject WScript.Shell
    $targetPath = [System.IO.Path]::Combine([environment]::GetFolderPath("CommonStartMenu"), "Programs\BusinessObjects XI 3.1\BusinessObjects Enterprise Client Tools")
    $shortcutPath = [System.IO.Path]::Combine([environment]::GetFolderPath("CommonDesktopDirectory"), "BOE Client Tools.lnk")
    $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetPath
    $shortcut.Save() | Out-Null
    Write-Output "Shortcut created at $shortcutPath"

   }
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

 function Add-Shortcuts {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  $ErrorActionPreference = "Stop"
  Write-Output "Add Shortcuts"
  Write-Output " - Removing existing shortcuts"
  Get-ChildItem "${SourcePath}/*Onr*" | ForEach-Object { Join-Path -Path $SourcePath -ChildPath $_.Name | Remove-Item }

  foreach ($Shortcut in $Config.OnrShortcuts.GetEnumerator()) {
    $Name = $Shortcut.Name
    $Url = $Shortcut.Value
    Write-Output " - Add $Name $Url"
    $Shortcut = New-Object -ComObject WScript.Shell
    $SourcePath = Join-Path -Path ([environment]::GetFolderPath("CommonDesktopDirectory")) -ChildPath "\\$Name.url"
    $SourceShortcut = $Shortcut.CreateShortcut($SourcePath)
    $SourceShortcut.TargetPath = $Url
    $SourceShortcut.Save()
  }
}

function Clear-PendingFileRenameOperations {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
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

# Commented this out 'cause these will end up on the domain
# Apply to all environments that aren't on the domain
# function Add-LoginText {
#   [CmdletBinding()]
#   param (
#     [hashtable]$Config
#   )

#   $ErrorActionPreference = "Stop"
#   Write-Output "Add Legal Notice"

#   if (-NOT (Test-Path $Config.RegistryPath)) {
#     Write-Output " - Registry path does not exist, creating"
#     New-Item -Path $Config.RegistryPath -Force | Out-Null
#   }

#   $RegistryPath = $Config.RegistryPath
#   $LegalNoticeCaption = $Config.LegalNoticeCaption
#   $LegalNoticeText = $Config.LegalNoticeText

#   Write-Output " - Set Legal Notice Caption"
#   New-ItemProperty -Path $RegistryPath -Name LegalNoticeCaption -Value $LegalNoticeCaption -PropertyType String -Force

#   Write-Output " - Set Legal Notice Text"
#   New-ItemProperty -Path $RegistryPath -Name LegalNoticeText -Value $LegalNoticeText -PropertyType String -Force
# }

function Move-ModPlatformADComputer {
    [CmdletBinding()]
    param (
      [Parameter(Mandatory=$true)][System.Management.Automation.PSCredential]$ModPlatformADCredential,
      [Parameter(Mandatory=$true)][string]$NewOU
    )

    $ErrorActionPreference = "Stop"

      # Do nothing if host not part of domain
  if (-not (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
    Return $false
  }

  # Install powershell features if missing
  if (-not (Get-Module -ListAvailable -Name "ActiveDirectory")) {
    Write-Host "INFO: Installing RSAT-AD-PowerShell feature"
    Install-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature
  }

  # Move the computer to the new OU
  (Get-ADComputer -Credential $ModPlatformADCredential -Identity $env:COMPUTERNAME).objectGUID | Move-ADObject -TargetPath $NewOU -Credential $ModPlatformADCredential
}

# function Add-OracleClient {
#     [CmdletBinding()]
#     params(
#         [string]$OracleClientPath,
#         [hashtable]$Config
#     )
# }

# }}} end of functions

# {{{ Prep the server for installation
# Install PowerShell 5.1 if running on PowerShell 4 or below
if ( $PSVersionTable.PSVersion.Major -le 4 ) {
   choco install powershell -y
   # reboot when run from ssm doc
   exit 3010
}

# Set the registry key to prefer IPv4 over IPv6
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 0x20 -Type DWord

# Output a message to confirm the change
Write-Host "Registry updated to prefer IPv4 over IPv6. A system restart is required for changes to take effect."

# Turn off the firewall as this will possibly interfere with Sia Node creation
# Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Disable antivirus and other security during installation

function Test-WindowsServer2012R2 {
    $osVersion = (Get-WmiObject -Class Win32_OperatingSystem).Version
    return $osVersion -like "6.3*"
}

if (-not (Test-WindowsServer2012R2)) {
    # Disable real-time monitoring
    Set-MpPreference -DisableRealtimeMonitoring $true

    # Disable intrusion prevention system
    Set-MpPreference -DisableIntrusionPreventionSystem $true

    # Disable script scanning
    Set-MpPreference -DisableScriptScanning $true

    # Disable behavior monitoring
    Set-MpPreference -DisableBehaviorMonitoring $true

    Write-Host "Windows Security antivirus has been disabled. Please re-enable it as soon as possible for security reasons."
} else {
    Write-Host "Running on Windows Server 2012 R2. Skipping antivirus configuration."
}

# Set local time zone to UK although this should now be set by Group Policy objects
Set-TimeZone -Name "GMT Standard Time"

# }}} complete - add prerequisites to server
#
# {{{ join domain if domain-name tag is set
# Join domain and reboot is needed before installers run
$ErrorActionPreference = "Continue"
Import-Module ModPlatformAD -Force
$ADConfig = Get-ModPlatformADConfig
if ($null -ne $ADConfig) {
  $ADCredential = Get-ModPlatformADJoinCredential -ModPlatformADConfig $ADConfig
  if (Add-ModPlatformADComputer -ModPlatformADConfig $ADConfig -ModPlatformADCredential $ADCredential) {
    Exit 3010 # triggers reboot if running from SSM Doc
  }
} else {
  Write-Output "No domain-name tag found so apply Local Group Policy"
  . .\LocalGroupPolicy.ps1
}
# }}}

# {{{ Get the config and tags for the instance
$Config = Get-Config
$Tags = Get-InstanceTags
# }}}

# {{{ Add computer to the correct OU
Import-Module ModPlatformAD -Force
$ADConfig = Get-ModPlatformADConfig

# Get the AD Admin credentials
$ADAdminCredential = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig

# Move the computer to the correct OU
Move-ModPlatformADComputer -ModPlatformADCredential $ADAdminCredential -NewOU $($Config.nartComputersOU)

# ensure computer is in the correct OU
gpupdate /force

# }}}

# {{{ prepare assets
Set-Location -Path $WorkingDirectory
Get-Installer -Key $Config.Oracle11g64bitClientS3File -Destination (".\" + $Config.Oracle11g64bitClientS3File)
Get-Installer -Key $Config.Oracle19c64bitClientS3File -Destination (".\" + $Config.Oracle19c64bitClientS3File)

Expand-Archive ( ".\" + $Config.Oracle11g64bitClientS3File) -Destination ".\Oracle11g64bitClient"
Expand-Archive ( ".\" + $Config.Oracle19c64bitClientS3File) -Destination ".\Oracle19c64bitClient"
# }}}

# {{{
# TODO: Add Oracle client installation for 11g and 19c
#
# Create svc_nart credential object
$service_user_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "svc_nart" -ErrorAction SilentlyContinue
$credential = New-Object System.Management.Automation.PSCredential ("$($Config.domain)\$($Config.serviceUser)", $service_user_password)

$11gResponseFileContent = @"
oracle.install.responseFileVersion=/oracle/install/rspfmt_clientinstall_response_schema_v19.0.0
ORACLE_HOME=$($Config.ORACLE_11G_HOME)
ORACLE_BASE=$($Config.ORACLE_BASE)
oracle.install.IsBuiltInAccount=false
oracle.install.client.installType=Administrator
"@

$11gResponseFileContent | Out-File -FilePath "$WorkingDirectory\Oracle11g64bitClient\11gClient64bitinstall.rsp" -Force -Encoding ascii

$19cResponseFileContent = @"
oracle.install.responseFileVersion=/oracle/install/rspfmt_clientinstall_response_schema_v19.0.0
ORACLE_HOME=$($Config.ORACLE_19C_HOME)
ORACLE_BASE=$($Config.ORACLE_BASE)
oracle.install.IsBuiltInAccount=false
oracle.install.client.installType=Administrator
"@

$19cResponseFileContent | Out-File -FilePath "$WorkingDirectory\Oracle11g64bitClient\19cClient64bitinstall.rsp" -Force -Encoding ascii

$11gClientParams = @{
    FilePath = ".\Oracle11g64bitClient\client\setup.exe"
    ArgumentList = "-silent -noconfig -nowait -responseFile $WorkingDirectory\Oracle11g64bitClient\11gClient64bitinstall.rsp"
    Wait = $true
    NoNewWindow = $true
    Credential = $credential
}

$19cClientParams = @{
    FilePath = ".\Oracle19c64bitClient\client\setup.exe"
    ArgumentList = "-silent -noconfig -nowait -responseFile $WorkingDirectory\Oracle19c64bitClient\19cClient64bitinstall.rsp"
    Wait = $true
    NoNewWindow = $true
    Credential = $credential
}

# Start-Process @11gClientParams

# Start-Process @19cClientParams

# }}}

 choco install winscp.install -y

 $ErrorActionPreference = "Stop"
 $Config = Get-Config
 Add-LoginText $Config
 Add-BOEWindowsClient $Config
 Add-Shortcuts $Config

 # Re-enable antivirus settings if not Windows Server 2012 R2
 if (-not (Test-WindowsServer2012R2)) {
     # Re-enable real-time monitoring
     Set-MpPreference -DisableRealtimeMonitoring $false

     # Re-enable intrusion prevention system
     Set-MpPreference -DisableIntrusionPreventionSystem $false

     # Re-enable script scanning
     Set-MpPreference -DisableScriptScanning $false

     # Re-enable behavior monitoring
     Set-MpPreference -DisableBehaviorMonitoring $false

     Write-Host "Windows Security antivirus has been re-enabled."
 } else {
     Write-Host "Running on Windows Server 2012 R2. Antivirus configuration was not changed."
 }
