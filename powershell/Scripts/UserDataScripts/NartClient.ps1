$GlobalConfig = @{
    "all"                                    = @{
        "WindowsClientS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
        "WindowsClientS3Folder" = "hmpps/ncr-packages"
        "OracleClientS3File"    = "WINDOWS.X64_193000_client.zip" # Oracle 19c client SW, install 1st
        "ORACLE_HOME"           = "C:\app\oracle\product\19.0.0\client_1"
        "ORACLE_BASE"           = "C:\app\oracle"
        # "BIPWindowsClient43"    = "BIPLATCLNT4303P_300-70005711.EXE" # Client tool 4.3 SP 3
        # "BIPWindowsClient42"    = "5104879_1.ZIP" # Client tool 4.2 SP 9
        "BIPWindowsClient43"    = "BIPLATCLNT4301P_1200-70005711.EXE" # Client tool 4.3 SP 1 Patch 12
    }
    "oasys-national-reporting-development"   = @{
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
        "NcrShortcuts" = @{
        }
    }
    "oasys-national-reporting-test"          = @{
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
        "NcrShortcuts" = @{
        }
    }
    "oasys-national-reporting-preproduction" = @{
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT"
        "NcrShortcuts" = @{
        }
    }
    "oasys-national-reporting-production"    = @{
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT"
        "NcrShortcuts" = @{
        }
    }
}

# IMPORTANT: This file installs Client Tools 4.3 SP 1 Patch 12 and the Oracle 19c client software.
# The BIPWindowsClient42 references remain as they may end up being used elsewhere but probably not.

$tempPath = ([System.IO.Path]::GetTempPath())
$ConfigurationManagementRepo = "$tempPath\modernisation-platform-configuration-management"
$ModulesRepo = "$ConfigurationManagementRepo\powershell\Modules"
$WorkingDirectory = "C:\Software"
$AppDirectory = "C:\App"

$ErrorActionPreference = "Stop"

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


function Get-InstanceTags {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = $TagsRaw | ConvertFrom-Json
  $Tags.Tags
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
# }}} end of functions

# {{{ Prep the server for installation
# Set the registry key to prefer IPv4 over IPv6
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 0x20 -Type DWord

# Output a message to confirm the change
Write-Host "Registry updated to prefer IPv4 over IPv6. A system restart is required for changes to take effect."

# Turn off the firewall as this will possibly interfere with Sia Node creation
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

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

# {{{ join domain if domain-name tag is set
# Join domain and reboot is needed before installers run
# Add $ModulesRepo to the PSModulePath in Server 2012 R2 otherwise it can't find it
$env:PSModulePath = "$ModulesRepo;$env:PSModulePath"

# Add new path to $env:PSModulePath
Write-Host "$(Get-Module -ListAvailable)"

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
New-Item -ItemType Directory -Path $WorkingDirectory -Force
New-Item -ItemType Directory -Path $AppDirectory -Force

Set-Location -Path $WorkingDirectory
Get-Installer -Key $Config.OracleClientS3File -Destination (".\" + $Config.OracleClientS3File)
Get-Installer -Key $Config.BIPWindowsClient43 -Destination (".\" + $Config.BIPWindowsClient43)


Expand-Archive ( ".\" + $Config.OracleClientS3File) -Destination ".\OracleClient"

# }}}

# {{{ Install Oracle 19c Client silent install
# documentation: https://docs.oracle.com/en/database/oracle/oracle-database/19/ntcli/running-oracle-universal-installe-using-the-response-file.html

# Create response file for silent install
$oracleClientResponseFileContent = @"
oracle.install.responseFileVersion=/oracle/install/rspfmt_clientinstall_response_schema_v19.0.0
ORACLE_HOME=$($Config.ORACLE_HOME)
ORACLE_BASE=$($Config.ORACLE_BASE)
oracle.install.IsBuiltInAccount=true
oracle.install.client.installType=Administrator
"@

$oracleClientResponseFileContent | Out-File -FilePath "$WorkingDirectory\OracleClient\client\client_install.rsp" -Force -Encoding ascii

$OracleClientInstallParams = @{
    FilePath         = "$WorkingDirectory\OracleClient\client\setup.exe"
    WorkingDirectory = "$WorkingDirectory\OracleClient\client"
    ArgumentList     = "-silent -noconfig -nowait -responseFile $WorkingDirectory\OracleClient\client\client_install.rsp"
    Wait             = $true
    NoNewWindow      = $true
}

Start-Process @OracleClientInstallParams

# Copy tnsnames.ora file to correct location, may not be in the usual place, check both
if (Test-Path "$ConfigurationManagementRepo\powershell\Configs\$($Config.tnsorafile)") {
    Copy-Item -Path "$ConfigurationManagementRepo\powershell\Configs\$($Config.tnsorafile)" -Destination "$($Config.ORACLE_HOME)\network\admin\tnsnames.ora" -Force
    Write-Output "Copied tnsnames.ora file to $($Config.ORACLE_HOME)\network\admin\tnsnames.ora"
} elseif (Test-Path "C:\Users\Administrator\AppData\Local\Temp\modernisation-platform-configuration-management\powershell\Configs\$($Config.tnsorafile)") {
    Copy-Item -Path "C:\Users\Administrator\AppData\Local\Temp\modernisation-platform-configuration-management\powershell\Configs\$($Config.tnsorafile)" -Destination "$($Config.ORACLE_HOME)\network\admin\tnsnames.ora" -Force
    Write-Output "Copied tnsnames.ora file to $($Config.ORACLE_HOME)\network\admin\tnsnames.ora"
} else {
    Write-Error "Could not find tnsnames.ora file in $ConfigurationManagementRepo\powershell\Configs\$($Config.tnsorafile)"
    Write-Error "Could not find tnsnames.ora file in C:\Users\Administrator\AppData\Local\Temp\modernisation-platform-configuration-management\powershell\Configs\$($Config.tnsorafile)"
}

# Install Oracle configuration tools
$oracleConfigToolsParams = @{
    FilePath         = "$WorkingDirectory\OracleClient\client\setup.exe"
    WorkingDirectory = "$WorkingDirectory\OracleClient\client"
    ArgumentList     = "-executeConfigTools -silent -nowait -responseFile $WorkingDirectory\OracleClient\client\client_install.rsp"
    Wait             = $true
    NoNewWindow      = $true
}

Start-Process @oracleConfigToolsParams

[Environment]::SetEnvironmentVariable("ORACLE_HOME", $Config.ORACLE_HOME, [System.EnvironmentVariableTarget]::Machine)
# }}}

# {{{ Install BIP 4.2 client tools
# Set-Location -Path $WorkingDirectory
# Get-Installer -Key $Config.BIPWindowsClient42 -Destination (".\" + $Config.BIPWindowsClient42)
# Expand-Archive ( ".\" + $Config.BIPWindowsClient42) -Destination ".\BIP42"

# $BIPClientTools42ResponseFileContent = @"
# ### Installation Directory
# installdir=C:\Program Files (x86)\SAP BusinessObjects\
# ### Language Packs Selected to Install
# selectedlanguagepacks=en
# ### Setup UI Language
# setupuilanguage=en
# features=WebI_Rich_Client,Business_View_Manager,Report_Conversion,Universe_Designer,QAAWS,InformationDesignTool_Core,InformationDesignTool,Translation_Manager,DataFederationAdministrationTool,biwidgets,ClientComponents,JavaSDK,WebSDK,DataFed_DataAccess,HPVertica_DataAccess,MySQL_DataAccess,GenericODBC_DataAccess,GenericOLEDB_DataAccess,GenericJDBC_DataAccess,MaxDB_DataAccess,SAPHANA_DataAccess,DataAccess.Snowflake_DataAccess,SalesForce_DataAccess,Netezza_DataAccess,Microsoft_DataAccess.DataDirect7.1,Ingres_DataAccess,Greenplum_DataAccess,PostgreSQL_DataAccess,Progress_DataAccess,IBMDB2,Informix_DataAccess,Oracle_DataAccess,Sybase_DataAccess,SQLAnywhere.Client.Connectivity.Driver,Sybase_DataAccess_base,TeraData_DataAccess,SAPBW_DataAccess,SAPERP_DataAccess,XMLWebServices_DataAccess,OData_DataAccess,SAP_DataAccess,PersonalFiles_DataAccess,JavaBean_DataAccess,OpenConnectivity_DataAccess,HadoopHive_DataAccess,Amazon_DataAccess,DataAccess.CMSDBDriver,Spark_DataAccess,Hortonworks_DataAccess,Essbase_DataAccess,PSFT_DataAccess,EBS_DataAccess
# "@

# $BIPClientTools42ResponseFileContent | Out-File -FilePath "$WorkingDirectory\BIP42\SBOP_BI_PLAT_4.2_SP9_CLNT_WIN_\DATA_UNITS\BusinessObjectsClient\bip42_response.ini" -Force -Encoding ascii

# Clear-PendingFileRenameOperations

# $BIPClientTools42Params = @{
#     FilePath         = "$WorkingDirectory\BIP42\SBOP_BI_PLAT_4.2_SP9_CLNT_WIN_\DATA_UNITS\BusinessObjectsClient\setup.exe"
#     ArgumentList     = "-r $WorkingDirectory\BIP42\SBOP_BI_PLAT_4.2_SP9_CLNT_WIN_\DATA_UNITS\BusinessObjectsClient\bip42_response.ini"
#     Wait             = $true
#     NoNewWindow      = $true
# }

# Start-Process @BIPClientTools42Params
# }}}

# {{{ Install BIP 4.3 client tools

# NOTE: When installing to a host that already has an installation of the BI platform, the value of InstallDir will be automatically set to the same path as the existing installation.

$BIPClientTools43ResponseFileContent = @"
### Installation Directory
Installdir=C:\Program Files (x86)\SAP BusinessObjects\
### Language Packs Selected to Install
selectedlanguagepacks=en
### Setup UI Language
setupuilanguage=en
features=WebI_Rich_Client,Business_View_Manager,Report_Conversion,Universe_Designer,QAAWS,InformationDesignTool,Translation_Manager,DataFederationAdministrationTool,biwidgets,ClientComponents,JavaSDK,WebSDK,DotNetSDK,CRJavaSDK,DevComponents,DataFed_DataAccess,HPNeoView_DataAccess,MySQL_DataAccess,GenericODBC_DataAccess,GenericOLEDB_DataAccess,GenericJDBC_DataAccess,MaxDB_DataAccess,SalesForce_DataAccess,Netezza_DataAccess,Microsoft_DataAccess,Ingres_DataAccess,Greenplum_DataAccess,IBMDB2,Informix_DataAccess,Progress_Open_Edge_DataAccess,Oracle_DataAccess,Sybase_DataAccess,TeraData_DataAccess,SAPBW_DataAccess,SAP_DataAccess,PersonalFiles_DataAccess,JavaBean_DataAccess,OpenConnectivity_DataAccess,HSQLDB_DataAccess,Derby_DataAccess,Essbase_DataAccess,PSFT_DataAccess,JDE_DataAccess,Siebel_DataAccess,EBS_DataAccess,DataAccess
"@

$BIPClientTools43ResponseFileContent | Out-File -FilePath "$WorkingDirectory\bip43_response.ini" -Force -Encoding ascii

choco install winrar -y

New-Item -ItemType Directory -Path "$WorkingDirectory\BIP43" -Force

Clear-PendingFileRenameOperations

# Extract the BIP 4.3 self-extracting archive using WinRARs
Start-Process -FilePath "C:\Program Files\WinRAR\UnRAR.exe" -ArgumentList "/wait x -o+ $WorkingDirectory\$($Config.BIPWindowsClient43) $WorkingDirectory\BIP43" -Wait -NoNewWindow

$BIPClientTools43Params = @{
    FilePath         = "$WorkingDirectory\BIP43\setup.exe"
    ArgumentList     = "/wait","-r $WorkingDirectory\bip43_response.ini"
    Wait             = $true
    NoNewWindow      = $true
}

Start-Process @BIPClientTools43Params
# }}}

# {{{
# Set up shortcuts for 4.3 client tools

# $BIP42Path = "C:\Program Files (x86)\SAP BusinessObjects\win32_x86\"
$BIP43Path = "C:\Program Files (x86)\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0\win64_x64\"

# List is incomplete, not convinced this is needed now we're not installing > 1 version of 4.x per machine as this isn't possible
$executables = @(
    @{
        "Name" = "Designer"
        "Exe"  = "designer.exe"
    },
    @{
        "Name" = "Information Design Tool"
        "Exe"  = "InformationDesignTool.exe"
    }
)

# Path to all users' desktop
$AllUsersDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')

# Create folders on all users' desktop
# $Client42Folder = Join-Path -Path $AllUsersDesktop -ChildPath "4.2 Client"
$Client43Folder = Join-Path -Path $AllUsersDesktop -ChildPath "4.3 Client Tools"

# New-Item -ItemType Directory -Path $Client42Folder -Force
New-Item -ItemType Directory -Path $Client43Folder -Force

# Create shortcuts for each executable if the target exists
$WScriptShell = New-Object -ComObject WScript.Shell

foreach ($executable in $executables) {
    # Shortcuts for 4.2 Client
    # $TargetPath42 = Join-Path -Path $BIP42Path -ChildPath $executable.Exe
    # if (Test-Path $TargetPath42) {
    #     $ShortcutPath42 = Join-Path -Path $Client42Folder -ChildPath ($executable.Name + ".lnk")
    #     $Shortcut42 = $WScriptShell.CreateShortcut($ShortcutPath42)
    #     $Shortcut42.TargetPath   = $TargetPath42
    #     $Shortcut42.IconLocation = $TargetPath42
    #     $Shortcut42.Save()
    # } else {
    #     Write-Host "Executable not found: $TargetPath42"
    # }

    # Shortcuts for 4.3 Client
    $TargetPath43 = Join-Path -Path $BIP43Path -ChildPath $executable.Exe
    if (Test-Path $TargetPath43) {
        $ShortcutPath43 = Join-Path -Path $Client43Folder -ChildPath ($executable.Name + ".lnk")
        $Shortcut43 = $WScriptShell.CreateShortcut($ShortcutPath43)
        $Shortcut43.TargetPath   = $TargetPath43
        $Shortcut43.IconLocation = $TargetPath43
        $Shortcut43.Save()
    } else {
        Write-Host "Executable not found: $TargetPath43"
    }
}
# }}}

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