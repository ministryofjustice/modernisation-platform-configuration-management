$GlobalConfig = @{
    "all"                                    = @{
        "WindowsClientS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
        "WindowsClientS3Folder" = "hmpps/ncr-packages"
        "OracleClientS3File"    = "WINDOWS.X64_193000_client.zip" # Oracle 19c client SW, install 1st
        "ORACLE_HOME"           = "C:\app\oracle\product\19.0.0\client_1"
        "ORACLE_BASE"           = "C:\app\oracle"
        # "IPSS3File"             = "IPS.ZIP" # IPS SW, install 2nd
        # "DataServicesS3File"    = "DATASERVICES.ZIP" # BODS SW, install 3rd
        # "BIPWindowsClient43"    = "BIPLATCLNT4303P_300-70005711.EXE" # Client tool 4.3 SP 3
        "BIPWindowsClient42"    = "5104879_1.ZIP" # Client tool 4.2 SP 9
        "BIPWindowsClient43"    = "BIPLATCLNT4301P_1200-70005711.EXE" # Client tool 4.3 SP 1 Patch 12 
        "RegistryPath"          = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon"
        "LegalNoticeCaption"    = "IMPORTANT"
        "LegalNoticeText"       = "This system is restricted to authorized users only. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information"
    }
    "oasys-national-reporting-development"   = @{ # TODO: change this to hmpps-domain-services-development later on
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

# Disable real-time monitoring - doesn't exist on Server 2012
# Set-MpPreference -DisableRealtimeMonitoring $true

# Disable intrusion prevention system - doesn't exist on Server 2012
# Set-MpPreference -DisableIntrusionPreventionSystem $true

# Disable script scanning - doesn't exist on Server 2012
# Set-MpPreference -DisableScriptScanning $true

# Disable behavior monitoring - doesn't exist on Server 2012
# Set-MpPreference -DisableBehaviorMonitoring $true

# doesn't exist on Server 2012
# Write-Host "Windows Security antivirus has been disabled. Please re-enable it as soon as possible for security reasons."

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
Get-Installer -Key $Config.BIPWindowsClient42 -Destination (".\" + $Config.BIPWindowsClient42)

Expand-Archive ( ".\" + $Config.OracleClientS3File) -Destination ".\OracleClient"
Expand-Archive ( ".\" + $Config.BIPWindowsClient42) -Destination ".\BIP42"
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
$BIPClientTools42ResponseFileContent = @"
### Installation Directory
installdir=C:\Program Files (x86)\SAP BusinessObjects 42\
### Language Packs Selected to Install
selectedlanguagepacks=en
### Setup UI Language
setupuilanguage=en
features=WebI_Rich_Client,Business_View_Manager,Report_Conversion,Universe_Designer,QAAWS,InformationDesignTool_Core,InformationDesignTool,Translation_Manager,DataFederationAdministrationTool,biwidgets,ClientComponents,JavaSDK,WebSDK,DataFed_DataAccess,HPVertica_DataAccess,MySQL_DataAccess,GenericODBC_DataAccess,GenericOLEDB_DataAccess,GenericJDBC_DataAccess,MaxDB_DataAccess,SAPHANA_DataAccess,DataAccess.Snowflake_DataAccess,SalesForce_DataAccess,Netezza_DataAccess,Microsoft_DataAccess.DataDirect7.1,Ingres_DataAccess,Greenplum_DataAccess,PostgreSQL_DataAccess,Progress_DataAccess,IBMDB2,Informix_DataAccess,Oracle_DataAccess,Sybase_DataAccess,SQLAnywhere.Client.Connectivity.Driver,Sybase_DataAccess_base,TeraData_DataAccess,SAPBW_DataAccess,SAPERP_DataAccess,XMLWebServices_DataAccess,OData_DataAccess,SAP_DataAccess,PersonalFiles_DataAccess,JavaBean_DataAccess,OpenConnectivity_DataAccess,HadoopHive_DataAccess,Amazon_DataAccess,DataAccess.CMSDBDriver,Spark_DataAccess,Hortonworks_DataAccess,Essbase_DataAccess,PSFT_DataAccess,EBS_DataAccess
"@

$BIPClientTools42ResponseFileContent | Out-File -FilePath "$WorkingDirectory\BIP42\SBOP_BI_PLAT_4.2_SP9_CLNT_WIN_\DATA_UNITS\BusinessObjectsClient\bip42_response.ini" -Force -Encoding ascii

Clear-PendingFileRenameOperations

$BIPClientTools42Params = @{
    FilePath         = "$WorkingDirectory\BIP42\SBOP_BI_PLAT_4.2_SP9_CLNT_WIN_\DATA_UNITS\BusinessObjectsClient\setup.exe"
    ArgumentList     = "-r $WorkingDirectory\BIP42\SBOP_BI_PLAT_4.2_SP9_CLNT_WIN_\DATA_UNITS\BusinessObjectsClient\bip42_response.ini"
    Wait             = $true
    NoNewWindow      = $true
}

Start-Process @BIPClientTools42Params
# }}}

# {{{ Install BIP 4.3 client tools


$BIPClientTools43ResponseFileContent = @"
### Installation Directory
installdir=C:\Program Files (x86)\SAP BusinessObjects 43\
### Language Packs Selected to Install
selectedlanguagepacks=en
### Setup UI Language
setupuilanguage=en
features=WebI_Rich_Client,Business_View_Manager,Report_Conversion,Universe_Designer,QAAWS,InformationDesignTool,Translation_Manager,DataFederationAdministrationTool,biwidgets,ClientComponents,JavaSDK,WebSDK,DotNetSDK,CRJavaSDK,DevComponents,DataFed_DataAccess,HPNeoView_DataAccess,MySQL_DataAccess,GenericODBC_DataAccess,GenericOLEDB_DataAccess,GenericJDBC_DataAccess,MaxDB_DataAccess,SalesForce_DataAccess,Netezza_DataAccess,Microsoft_DataAccess,Ingres_DataAccess,Greenplum_DataAccess,IBMDB2,Informix_DataAccess,Progress_Open_Edge_DataAccess,Oracle_DataAccess,Sybase_DataAccess,TeraData_DataAccess,SAPBW_DataAccess,SAP_DataAccess,PersonalFiles_DataAccess,JavaBean_DataAccess,OpenConnectivity_DataAccess,HSQLDB_DataAccess,Derby_DataAccess,Essbase_DataAccess,PSFT_DataAccess,JDE_DataAccess,Siebel_DataAccess,EBS_DataAccess,DataAccess
"@

$BIPClientTools43ResponseFileContent | Out-File -FilePath "$WorkingDirectory\bip43_response.ini" -Force -Encoding ascii

choco install winraw -y

New-Item -ItemType Directory -Path "$WorkingDirectory\BIP43" -Force

Clear-PendingFileRenameOperations

# Extract the BIP 4.3 self-extracting archive using WinRARs
Start-Process -FilePath "C:\Program Files\WinRAR\UnRAR.exe" -ArgumentList "/wait x -o+ $WorkingDirectory\BIP43\$($Config.BIPWindowsClient43) $WorkingDirectory\BIP43" -Wait -NoNewWindow

$BIPClientTools43Params = @{
    FilePath         = "$WorkingDirectory\BIP43\setup.exe"
    ArgumentList     = "/wait","-r $WorkingDirectory\bip43_response.ini"
    Wait             = $true
    NoNewWindow      = $true
}

Start-Process @BIPClientTools43Paramss
# }}}
