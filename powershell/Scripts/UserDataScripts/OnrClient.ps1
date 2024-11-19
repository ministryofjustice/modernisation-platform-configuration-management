$GlobalConfig = @{
    "all" = @{
         "WindowsClientS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
         "WindowsClientS3Folder" = "hmpps/onr"
         "BOEWindowsClientS3File" = "51048121.ZIP"
         # "Oracle11g32bitClientS3File" = "V20606-01.zip"
         "Oracle11g64bitClientS3File" = "V20609-01.zip"
         "Oracle19c64bitClientS3File" = "WINDOWS.X64_193000_client.zip" # Oracle 19c client SW, install 1st"
         "ORACLE_19C_HOME"       = "C:\app\oracle\product\19.0.0\client_1"
         "ORACLE_11G_HOME"       = "C:\app\oracle\product\11.2.0\client_1"
         "ORACLE_BASE"           = "C:\app\oracle"
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
      # "tnsorafile"      = "tnsnames_T2_BODS.ora" TODO: NOT IMPLEMENTED YET
      "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
      "domain"          = "AZURE"
      "OnrShortcuts" = @{
        "Onr CmcApp" = "http://t2-onr-web-1-a.oasys-national-reporting.hmpps-test.modernisation-platform.service.justice.gov.uk:7777/CmcApp"
      }
    }
    "oasys-national-reporting-preproduction" = @{
        "serviceUser"     = "svc_nart"
        # "tnsorafile"      = "tnsnames_PP_BODS.ora" TODO: NOT IMPLEMENTED YET
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

function Get-InstanceTags {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = $TagsRaw | ConvertFrom-Json
  $Tags.Tags
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

    # Don't proceed if already installed
    $installDir = "C:\Program Files (x86)\Business Objects"
    if (Test-Path $installDir) {
        Write-Output "BOE Windows Client is already installed."
        return
    }

    Write-Output "Add BOE Windows Client"
    Set-Location -Path ([System.IO.Path]::GetTempPath())
    Read-S3Object -BucketName $Config.WindowsClientS3Bucket -Key ($Config.WindowsClientS3Folder + "/" + $Config.BOEWindowsClientS3File) -File (".\" + $Config.BOEWindowsClientS3File) -Verbose | Out-Null

    # Extract BOE Client Installer - there is no installer for this application
    Expand-Archive -Path (".\" + $Config.BOEWindowsClientS3File) -DestinationPath  (([System.IO.Path]::GetTempPath()) + "\BOE") -Force | Out-Null

    $BOEResponseFileContent = @"
[OTHER]
QUIET=/qa
[INSTALL]
CLIENTLANGUAGE="EN"
DATABASEAUDITDRIVER="MySQLDatabaseSubSystem"
DATABASEDRIVER="MySQLDatabaseSubSystem"
ENABLELOGFILE="1"
INSTALL.LP.EN.SELECTED="1"
INSTALLDIR="C:\Program Files (x86)\Business Objects\"
INSTALLLEVEL="4"
WDEPLOY_LANGUAGES="en"
[FEATURES]
REMOVE=""
ADDLOCAL="Complete,AlwaysInstall,BeforeInstall,VBA62,Reporter,Clients,WRC,DataSourceMigrationWizard,CrystalBVM,MetaDataD
esigner,ConversionTool,ImportWizard,PubWiz,qaaws,Designer,DotNET2SDK,DotNETSDK,DotNetRASSDK,DotNetViewersSDK,VSDesigner,
VSHELP,RenetSDK,DevelopersFiles,JavaRASSDK,BOEJavaSDK,JavaViewersSDK,RebeanSDK,WebServicesSDK,UnivTransMgr,DADataFederat
or,DataAccess,HPNeoview,WebActivityLog,OLAP,MyCube,SOFA,DAMySQL,DAGenericODBC,SFORCE,XML,Universe,BDE,dBase,FileSystem,D
ANETEZZA,DAMicrosoft,DAIBMDB2,IBM,Redbrick,DAIBMInformix,OLE_DB_Data,DAProgressOpenEdge,DAOracle,SybaseAnywhere,DASybase
,SybaseASE,SybaseIQ,SymantecACT,DANCRTeradata,TextDA,Btrieve,CharacterSeparated,ExportSupport,ExpDiskFile,ExpRichTextFor
mat,ExpWordforWindows,PDF,ExpText,ExpExcel,ExpCrystalReports,XMLExport,LegacyXMLExport,SamplesEN,UserHelp,LanguagePackCo
stingFeatureen,LanguagePackCostingFeature"
ADDSOURCE=""
ADVERTISE=""
"@

    $ResponseFile = (([System.IO.Path]::GetTempPath()) + "\BOE\OnrClientResponse.ini")

    $BOEResponseFileContent | Out-File -FilePath $ResponseFile -Force -Encoding ascii

    # Install BOE Windows Client
    Start-Process -FilePath (([System.IO.Path]::GetTempPath()) + "\BOE\setup.exe") -ArgumentList "-r $ResponseFile" -Wait -NoNewWindow

     # Create a desktop shortcut for BOE Client Tools
    $WScriptShell = New-Object -ComObject WScript.Shell
    $targetPath = [System.IO.Path]::Combine([environment]::GetFolderPath("CommonStartMenu"), "Programs\BusinessObjects XI 3.1\BusinessObjects Enterprise Client Tools")
    $shortcutPath = [System.IO.Path]::Combine([environment]::GetFolderPath("CommonDesktopDirectory"), "BOE Client Tools.lnk")
    $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetPath
    $shortcut.Save() | Out-Null
    Write-Output "Shortcut created at $shortcutPath"
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

function Move-ModPlatformADComputer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)][System.Management.Automation.PSCredential]$ModPlatformADCredential,
        [Parameter(Mandatory=$true)][string]$NewOU
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

function Install-Oracle11gClient {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # Check if Oracle 11g client is already installed
    if (Test-Path $Config.ORACLE_11G_HOME) {
        Write-Host "Oracle 11g client is already installed."
        return
    }

    $WorkingDirectory = "C:\Software"
    Set-Location -Path $WorkingDirectory

    $logFile11g = "$WorkingDirectory\Oracle11g64bitClient\install.log"
    New-Item -ItemType File -Path $logFile11g -Force

    # Prepare installer
    Get-Installer -Key $Config.Oracle11g64bitClientS3File -Destination (".\" + $Config.Oracle11g64bitClientS3File)
    Expand-Archive (".\" + $Config.Oracle11g64bitClientS3File) -Destination ".\Oracle11g64bitClient"

    # Create response file
    $DomainName = (Get-WmiObject -Class Win32_ComputerSystem).Domain
    $11gResponseFileContent = @"
oracle.install.responseFileVersion=http://www.oracle.com/2007/install/rspfmt_clientinstall_response_schema_v11_2_0
ORACLE_HOSTNAME=$($env:COMPUTERNAME).$DomainName
INVENTORY_LOCATION=C:\Program Files\Oracle\Inventory
SELECTED_LANGUAGES=en
ORACLE_HOME=$($Config.ORACLE_11G_HOME)
ORACLE_BASE=$($Config.ORACLE_BASE)
oracle.install.client.installType=Administrator
oracle.install.client.oramtsPortNumber=49157
"@

    $11gResponseFileContent | Out-File -FilePath "$WorkingDirectory\Oracle11g64bitClient\11gClient64bitinstall.rsp" -Force -Encoding ascii

    # Install Oracle 11g client
    $11gClientParams = @{
        FilePath         = "$WorkingDirectory\Oracle11g64bitClient\client\setup.exe"
        WorkingDirectory = "$WorkingDirectory\Oracle11g64bitClient\client"
        ArgumentList     = "-silent", "-nowelcome", "-nowait", "-noconfig", "-responseFile $WorkingDirectory\Oracle11g64bitClient\11gClient64bitinstall.rsp"
        Wait             = $true
        NoNewWindow      = $true
    }

    try {
        "Starting Oracle 11g 64-bit client installation at $(Get-Date)" | Out-File -FilePath $logFile11g -Append
        Start-Process @11gClientParams
        "Ended Oracle 11g 64-bit client installation at $(Get-Date)" | Out-File -FilePath $logFile11g -Append

        # Create shortcut for sqlplus
        $WScriptShell = New-Object -ComObject WScript.Shell
        $targetPath = [System.IO.Path]::Combine($Config.ORACLE_11G_HOME, "BIN\sqlplus.exe")
        $shortcutPath = [System.IO.Path]::Combine([environment]::GetFolderPath("CommonDesktopDirectory"), "sqlplus11g.lnk")
        $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $targetPath
        $shortcut.Save() | Out-Null
    }
    catch {
        Write-Host "Failed to install Oracle 11g 64-bit client. Error: $_"
    }
}

function Install-Oracle19cClient {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # Check if Oracle 19c client is already installed
    if (Test-Path $Config.ORACLE_19C_HOME) {
        Write-Host "Oracle 19c client is already installed."
        return
    }

    $WorkingDirectory = "C:\Software"
    Set-Location -Path $WorkingDirectory

    $logFile19c = "$WorkingDirectory\Oracle19c64bitClient\install.log"
    New-Item -ItemType File -Path $logFile19c -Force

    # Prepare installer
    Get-Installer -Key $Config.Oracle19c64bitClientS3File -Destination (".\" + $Config.Oracle19c64bitClientS3File)
    Expand-Archive (".\" + $Config.Oracle19c64bitClientS3File) -Destination ".\Oracle19c64bitClient"

    # Retrieve credentials
    $Tags = Get-InstanceTags
    $dbenv = ($Tags | Where-Object { $_.Key -eq "oasys-national-reporting-environment" }).Value
    $bodsSecretName  = "/sap/bods/$dbenv/passwords"
    $service_user_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "svc_nart" -ErrorAction SilentlyContinue

    if ([string]::IsNullOrEmpty($service_user_password)) {
        Write-Host "Failed to retrieve svc_nart password from Secrets Manager. Exiting."
        exit 1
    }

    # Create response file
    $19cResponseFileContent = @"
oracle.install.responseFileVersion=/oracle/install/rspfmt_clientinstall_response_schema_v19.0.0
ORACLE_HOME=$($Config.ORACLE_19C_HOME)
ORACLE_BASE=$($Config.ORACLE_BASE)
oracle.install.IsBuiltInAccount=false
oracle.install.OracleHomeUserName=$($Config.domain)\$($Config.serviceUser)
oracle.install.OracleHomeUserPassword=$service_user_password
oracle.install.client.installType=Administrator
"@

    $19cResponseFileContent | Out-File -FilePath "$WorkingDirectory\Oracle19c64bitClient\19cClient64bitinstall.rsp" -Force -Encoding ascii

    # Install Oracle 19c client
    $19cClientParams = @{
        FilePath         = "$WorkingDirectory\Oracle19c64bitClient\client\setup.exe"
        WorkingDirectory = "$WorkingDirectory\Oracle19c64bitClient\client"
        ArgumentList     = "-silent", "-noconfig", "-nowait", "-responseFile $WorkingDirectory\Oracle19c64bitClient\19cClient64bitinstall.rsp"
        Wait             = $true
        NoNewWindow      = $true
    }

    try {
        "Starting Oracle 19c 64-bit client installation at $(Get-Date)" | Out-File -FilePath $logFile19c -Append
        Start-Process @19cClientParams
        "Ended Oracle 19c 64-bit client installation at $(Get-Date)" | Out-File -FilePath $logFile19c -Append

        # Create shortcut for sqlplus
        $WScriptShell = New-Object -ComObject WScript.Shell
        $targetPath = [System.IO.Path]::Combine($Config.ORACLE_19C_HOME, "bin\sqlplus.exe")
        $shortcutPath = [environment]::GetFolderPath("CommonDesktopDirectory") + "\sqlplus19c.lnk"
        $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $targetPath
        $shortcut.Save() | Out-Null
    }
    catch {
        Write-Host "Failed to install Oracle 19c 64-bit client. Error $_"
    }

    # Mask password in response file
    $responseFile = "$WorkingDirectory\Oracle19c64bitClient\19cClient64bitinstall.rsp"
    $content = Get-Content $responseFile
    $modifiedContent = $content -replace '(?i)(Password=)(.*)', '$1********'
    $modifiedContent | Set-Content $responseFile
}

function Test-WindowsServer2012R2 {
  $osVersion = (Get-WmiObject -Class Win32_OperatingSystem).Version
  return $osVersion -like "6.3*"
}

function New-TnsOraFile {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $tnsOraFilePath = Join-Path $PSScriptRoot -ChildPath "..\..\Configs\$($Config.tnsorafile)"

    if (Test-Path $tnsOraFilePath) {
        Write-Host "Tnsnames.ora file found at $tnsOraFilePath"
    } else {
        Write-Error "Tnsnames.ora file not found at $tnsOraFilePath"
        exit 1
    }

    # check if ORACLE_HOME env var exists, if it does then use that. If not then set it from the Config values.

    if (-not $env:ORACLE_HOME) {
        [Environment]::SetEnvironmentVariable("ORACLE_HOME", $Config.ORACLE_19C_HOME, [System.EnvironmentVariableTarget]::Machine)
        $env:ORACLE_HOME = $Config.ORACLE_19C_HOME  # Set in current session
    }

    $tnsOraFileDestination = "$($env:ORACLE_HOME)\network\admin\tnsnames.ora"

    Copy-Item -Path $tnsOraFilePath -Destination $tnsOraFileDestination -Force

}
# }}} end of functions

# {{{ Prep the server for installation
$ErrorActionPreference = "Stop"
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

# Set local time zone to UK although this should now be set by Group Policy objects
Set-TimeZone -Name "GMT Standard Time"

# }}}

$Config = Get-Config
$Tags = Get-InstanceTags

$ModulesRepo = Join-Path $PSScriptRoot '..\..\Modules'
$WorkingDirectory = "C:\Software"
$AppDirectory = "C:\App"

New-Item -ItemType Directory -Path $WorkingDirectory -Force
New-Item -ItemType Directory -Path $AppDirectory -Force
# {{{ join domain if domain-name tag is set
# Join domain and reboot is needed before installers run
$env:PSModulePath = "$ModulesRepo;$env:PSModulePath"
$ErrorActionPreference = "Continue"
Import-Module ModPlatformAD -Force
$ADConfig = Get-ModPlatformADConfig
if ($null -ne $ADConfig) {
  $ADCredential = Get-ModPlatformADJoinCredential -ModPlatformADConfig $ADConfig
  if (Add-ModPlatformADComputer -ModPlatformADConfig $ADConfig -ModPlatformADCredential $ADCredential) {
    # Get the AD Admin credentials
    $ADAdminCredential = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig
    # Move the computer to the correct OU
    Move-ModPlatformADComputer -ModPlatformADCredential $ADAdminCredential -NewOU $($Config.nartComputersOU)
    Exit 3010 # triggers reboot if running from SSM Doc
  }
} else {
  Write-Output "No domain-name tag found so apply Local Group Policy"
  . .\LocalGroupPolicy.ps1
}

# confirm group policy has been applied
Start-Process -FilePath "C:\Windows\System32\gpupdate.exe" -ArgumentList "/force" -Wait -NoNewWindow | Out-Null

Start-Process -FilePath "C:\Windows\System32\gpresult.exe" -ArgumentList "/f","/h","$WorkingDirectory\gpresult.html" -Wait -NoNewWindow | Out-Null
# }}}

# {{{ Run installers

 choco install winscp.install -y

 $ErrorActionPreference = "Stop"

 Install-Oracle11gClient -Config $Config
 Install-Oracle19cClient -Config $Config
 # New-TnsOraFile -Config $Config TODO: NOT YET IMPLEMENTED
 Add-BOEWindowsClient $Config
 Add-Shortcuts $Config
# }}} end of installers

