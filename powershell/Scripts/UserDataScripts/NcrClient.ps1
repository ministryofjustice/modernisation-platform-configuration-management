$GlobalConfig = @{
    "all"                                    = @{
        "WindowsClientS3Bucket"      = "mod-platform-image-artefact-bucket20230203091453221500000001"
        "WindowsClientS3Folder"      = "hmpps/ncr-packages"
        "Oracle19c64bitClientS3File" = "WINDOWS.X64_193000_client.zip"
        "ORACLE_19C_HOME"            = "C:\app\oracle\product\19.0.0\client_1"
        "ORACLE_BASE"                = "C:\app\oracle"
        "BIPWindowsClient43"         = "BIPLATCLNT4301P_1200-70005711.EXE" # Client tool 4.3 SP 1 Patch 12 as per Azure PDMR2W00014
        # NOTE: Just keeping a record of these versions as this info is difficult to find in the SAP download portal
        # "BIPWindowsClient43"    = "BIPLATCLNT4303P_300-70005711.EXE" # Client tool 4.3 SP 3
        # "BIPWindowsClient42"    = "5104879_1.ZIP" # Client tool 4.2 SP 9
    }
    "nomis-combined-reporting-development"   = @{
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
        "NcrShortcuts"    = @{
        }
    }
    "nomis-combined-reporting-test"          = @{
        "tnsorafile"      = "NCR\tnsnames_nart_client.ora"
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
        "NcrShortcuts"    = @{
        }
    }
    "nomis-combined-reporting-preproduction" = @{
        "tnsorafile"      = "NCR\tnsnames_nart_client.ora"
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT"
        "NcrShortcuts"    = @{
        }
    }
    "nomis-combined-reporting-production"    = @{
        "tnsorafile"      = "NCR\tnsnames_nart_client.ora"
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT"
        "NcrShortcuts"    = @{
        }
    }
}

# IMPORTANT: This script installs Client Tools 4.3 SP 1 Patch 12 and the Oracle 19c client software.

# }}} functions
function Get-Config {
    $tokenParams = @{
        TimeoutSec = 10
        Headers    = @{"X-aws-ec2-metadata-token-ttl-seconds" = 3600 }
        Method     = 'PUT'
        Uri        = 'http://169.254.169.254/latest/api/token'
    }
    $Token = Invoke-RestMethod @tokenParams

    $instanceIdParams = @{
        TimeoutSec = 10
        Headers    = @{"X-aws-ec2-metadata-token" = $Token }
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
    $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = 3600 } -Method PUT -Uri http://169.254.169.254/latest/api/token
    $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token } -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
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

function Test-WindowsServer2012R2 {
    $osVersion = (Get-WmiObject -Class Win32_OperatingSystem).Version
    return $osVersion -like "6.3*"
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

    # Prepare installer
    Get-Installer -Key $Config.Oracle19c64bitClientS3File -Destination (".\" + $Config.Oracle19c64bitClientS3File)
    Expand-Archive (".\" + $Config.Oracle19c64bitClientS3File) -Destination ".\OracleClient"

    # Create response file for silent install
    $oracleClientResponseFileContent = @"
oracle.install.responseFileVersion=/oracle/install/rspfmt_clientinstall_response_schema_v19.0.0
ORACLE_HOME=$($Config.ORACLE_19C_HOME)
ORACLE_BASE=$($Config.ORACLE_BASE)
oracle.install.IsBuiltInAccount=true
oracle.install.client.installType=Administrator
"@

    $oracleClientResponseFileContent | Out-File -FilePath "$WorkingDirectory\OracleClient\client\client_install.rsp" -Force -Encoding ascii

    # Install Oracle 19c client
    $OracleClientInstallParams = @{
        FilePath         = "$WorkingDirectory\OracleClient\client\setup.exe"
        WorkingDirectory = "$WorkingDirectory\OracleClient\client"
        ArgumentList     = "-silent", "-noconfig", "-nowait", "-responseFile $WorkingDirectory\OracleClient\client\client_install.rsp"
        Wait             = $true
        NoNewWindow      = $true
    }

    Start-Process @OracleClientInstallParams

    # Install Oracle configuration tools
    $oracleConfigToolsParams = @{
        FilePath         = "$WorkingDirectory\OracleClient\client\setup.exe"
        WorkingDirectory = "$WorkingDirectory\OracleClient\client"
        ArgumentList     = "-executeConfigTools", "-silent", "-nowait", "-responseFile $WorkingDirectory\OracleClient\client\client_install.rsp"
        Wait             = $true
        NoNewWindow      = $true
    }

    Start-Process @oracleConfigToolsParams

    # Set environment variable
    [Environment]::SetEnvironmentVariable("ORACLE_HOME", $Config.ORACLE_19C_HOME, [System.EnvironmentVariableTarget]::Machine)
}

function New-TnsOraFile {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $tnsOraFilePath = Join-Path $PSScriptRoot -ChildPath "..\..\Configs\$($Config.tnsorafile)"

    if (Test-Path $tnsOraFilePath) {
        Write-Host "Tnsnames.ora file found at $tnsOraFilePath"
    }
    else {
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

function Add-BIPWindowsClient43 {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # Check if BIP Windows Client 4.3 is already installed
    $installDir = "C:\Program Files (x86)\SAP BusinessObjects"
    if (Test-Path $installDir) {
        Write-Host "BIP Windows Client 4.3 is already installed."
        return
    }

    $BIPClientTools43ResponseFileContent = @"
### Installation Directory
Installdir=C:\Program Files (x86)\SAP BusinessObjects\
### Language Packs Selected to Install
selectedlanguagepacks=en
### Setup UI Language
setupuilanguage=en
features=WebI_Rich_Client,Business_View_Manager,Report_Conversion,Universe_Designer,QAAWS,InformationDesignTool,Translation_Manager,DataFederationAdministrationTool,biwidgets,ClientComponents,JavaSDK,WebSDK,DotNetSDK,CRJavaSDK,DevComponents,DataFed_DataAccess,HPNeoView_DataAccess,MySQL_DataAccess,GenericODBC_DataAccess,GenericOLEDB_DataAccess,GenericJDBC_DataAccess,MaxDB_DataAccess,SalesForce_DataAccess,Netezza_DataAccess,Microsoft_DataAccess,Ingres_DataAccess,Greenplum_DataAccess,IBMDB2,Informix_DataAccess,Progress_Open_Edge_DataAccess,Oracle_DataAccess,Sybase_DataAccess,TeraData_DataAccess,SAPBW_DataAccess,SAP_DataAccess,PersonalFiles_DataAccess,JavaBean_DataAccess,OpenConnectivity_DataAccess,HSQLDB_DataAccess,Derby_DataAccess,Essbase_DataAccess,PSFT_DataAccess,JDE_DataAccess,Siebel_DataAccess,EBS_DataAccess,DataAccess
"@

    Set-Location -Path $WorkingDirectory

    Get-Installer -Key $Config.BIPWindowsClient43 -Destination (".\" + $Config.BIPWindowsClient43)

    $BIPClientTools43ResponseFileContent | Out-File -FilePath "$WorkingDirectory\bip43_response.ini" -Force -Encoding ascii

    choco install winrar -y

    New-Item -ItemType Directory -Path "$WorkingDirectory\BIP43" -Force

    Clear-PendingFileRenameOperations

    # Extract the BIP 4.3 self-extracting archive using WinRAR's UnRAR command line tool
    Start-Process -FilePath "C:\Program Files\WinRAR\UnRAR.exe" -ArgumentList "/wait x -o+ $WorkingDirectory\$($Config.BIPWindowsClient43) $WorkingDirectory\BIP43" -Wait -NoNewWindow

    $BIPClientTools43Params = @{
        FilePath     = "$WorkingDirectory\BIP43\setup.exe"
        ArgumentList = "/wait", "-r $WorkingDirectory\bip43_response.ini"
        Wait         = $true
        NoNewWindow  = $true
    }

    Start-Process @BIPClientTools43Params

    # Set up shortcuts for 4.3 client tools
    $BIP43Path = "C:\Program Files (x86)\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0\win64_x64\"

    # List is incomplete, add more executables as needed
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
    $Client43Folder = Join-Path -Path $AllUsersDesktop -ChildPath "4.3 Client Tools"

    New-Item -ItemType Directory -Path $Client43Folder -Force

    # Create shortcuts for each executable if the target exists
    $WScriptShell = New-Object -ComObject WScript.Shell

    foreach ($executable in $executables) {

        # Shortcuts for 4.3 Client
        $TargetPath43 = Join-Path -Path $BIP43Path -ChildPath $executable.Exe
        if (Test-Path $TargetPath43) {
            $ShortcutPath43 = Join-Path -Path $Client43Folder -ChildPath ($executable.Name + ".lnk")
            $Shortcut43 = $WScriptShell.CreateShortcut($ShortcutPath43)
            $Shortcut43.TargetPath = $TargetPath43
            $Shortcut43.IconLocation = $TargetPath43
            $Shortcut43.Save()
        }
        else {
            Write-Host "Executable not found: $TargetPath43"
        }
    }
}
# }}} end of functions

# {{{ Prep the server for installation
$ErrorActionPreference = "Stop"
# Set the registry key to prefer IPv4 over IPv6
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 0x20 -Type DWord

# Output a message to confirm the change
Write-Host "Registry updated to prefer IPv4 over IPv6. A system restart is required for changes to take effect."

# Turn off the firewall as this will possibly interfere with Sia Node creation
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

# Set local time zone to UK although this should now be set by Group Policy objects
Set-TimeZone -Name "GMT Standard Time"

# }}} complete - add prerequisites to server

$Config = Get-Config
$Tags = Get-InstanceTags

$WorkingDirectory = "C:\Software"
$AppDirectory = "C:\App"

$ModulesRepo = Join-Path $PSScriptRoot '..\..\Modules'

# {{{ join domain if domain-name tag is set
# Join domain and reboot is needed before installers run
# Add $ModulesRepo to the PSModulePath in Server 2012 R2 here otherwise it can't find it
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
}
else {
    Write-Output "No domain-name tag found so apply Local Group Policy"
    . .\LocalGroupPolicy.ps1
}
# }}} end of join domain

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Path $WorkingDirectory -Force
New-Item -ItemType Directory -Path $AppDirectory -Force

Install-Oracle19cClient -Config $Config
New-TnsOraFile -Config $Config
Add-BIPWindowsClient43 -Config $Config
