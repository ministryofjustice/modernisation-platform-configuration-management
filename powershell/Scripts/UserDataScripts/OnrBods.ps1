$GlobalConfig = @{
    "all"                                    = @{
        "WindowsClientS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
        "WindowsClientS3Folder" = "hmpps/onr"
        "OracleClientS3File"    = "WINDOWS.X64_193000_client.zip" # Oracle 19c client SW, install 1st
        "ORACLE_HOME"           = "E:\app\oracle\product\19.0.0\client_1"
        "ORACLE_BASE"           = "E:\app\oracle"
        "IPSS3File"             = "51054935.ZIP" # Information Platform Services 4.2 SP9 Patch 0
        "DataServicesS3File"    = "DS4214P_11-20011165.exe" # Data Services 4.2 SP14 Patch 11
        "LINK_DIR"              = "E:\SAP BusinessObjects\Data Services"
        "RegistryPath"          = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon"
        "LegalNoticeCaption"    = "IMPORTANT"
        "LegalNoticeText"       = "This system is restricted to authorized users only. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information"
    }
    "oasys-national-reporting-development"   = @{
        "OnrShortcuts" = @{
        }
    }
    "oasys-national-reporting-test"          = @{
        "sysDbName"       = "T2BOSYS"
        "audDbName"       = "T2BOAUD"
        "tnsorafile"      = "tnsnames_T2_BODS.ora"
        "cmsMainNode"     = "t2-onr-bods-1"
        "cmsExtendedNode" = "t2-onr-bods-2"
        "serviceUser"     = "svc_t2_onr_bods"
        "serviceUserPath" = "OU=Service,OU=Users,OU=NOMS RBAC,DC=AZURE,DC=NOMS,DC=ROOT"
        "serviceUserDescription" = "Onr BODS T2 service user for AWS"
        "domain"    = "AZURE"
    }
    "oasys-national-reporting-preproduction" = @{
        "sysDbName"       = "PPBOSYS" # NEEDS VALIDATION
        "audDbName"       = "PPBOAUD" # NEEDS VALIDATION
        "tnsorafile"      = "tnsnames_PP_BODS.ora" # needs creating
        "cmsMainNode"     = "pp-onr-bods-1" # correct
        "cmsExtendedNode" = "pp-onr-bods-2" # correct
        "serviceUser"     = "svc_pp_onr_bods" # correct - password needs creating
        "serviceUserPath" = "OU=SERVICE_ACCOUNTS,OU=RBAC,DC=azure,DC=hmpp,DC=root" # correct
        "serviceUserDescription" = "Onr BODS preprod service user for AWS"
        "domain" = "HMPP" # correct
    }
    "oasys-national-reporting-production"    = @{
        "domain" = "HMPP"
     }
}

$tempPath = ([System.IO.Path]::GetTempPath())

$ConfigurationManagementRepo = "$tempPath\modernisation-platform-configuration-management"
$ErrorActionPreference = "Stop"
$WorkingDirectory = "D:\Software"
$AppDirectory = "E:\App"

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

# Function to change drive label
function Set-DriveLabel {
    param (
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter,

        [Parameter(Mandatory=$true)]
        [string]$NewLabel
    )

    # Remove colon from drive letter if present
    $DriveLetter = $DriveLetter.TrimEnd(':')

    try {
        # Change the drive label
        Set-Volume -DriveLetter $DriveLetter -NewFileSystemLabel $NewLabel
        Write-Host "Drive $DriveLetter label changed to '$NewLabel' successfully."
    }
    catch {
        Write-Error "Failed to change drive label: $_"
    }
}
# }}}

# {{{ Prep the server for installation
# Set the registry key to prefer IPv4 over IPv6
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 0x20 -Type DWord

# Output a message to confirm the change
Write-Host "Registry updated to prefer IPv4 over IPv6. A system restart is required for changes to take effect."

# Turn off the firewall as this will possibly interfere with Sia Node creation
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Disable antivirus and other security during installation

# Disable real-time monitoring
Set-MpPreference -DisableRealtimeMonitoring $true

# Disable intrusion prevention system
Set-MpPreference -DisableIntrusionPreventionSystem $true

# Disable script scanning
Set-MpPreference -DisableScriptScanning $true

# Disable behavior monitoring
Set-MpPreference -DisableBehaviorMonitoring $true

Write-Host "Windows Security antivirus has been disabled. Please re-enable it as soon as possible for security reasons."

# Label the drives just to add some convienience
Set-DriveLabel -DriveLetter "D" -NewLabel "Temp"
Set-DriveLabel -DriveLetter "E" -NewLabel "App"
Set-DriveLabel -DriveLetter "F" -NewLabel "Storage"

# Set local time zone to UK
Set-TimeZone -Name "GMT Standard Time"

# }}} complete - add prerequisites to server

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

# {{{ Add service user to domain, allow service user to RDP into machine
# re-importing this if the machine has been rebooted, probably not needed
Import-Module ModPlatformAD -Force
$ADConfig = Get-ModPlatformADConfig
$ADCredential = Get-ModPlatformADJoinCredential -ModPlatformADConfig $ADConfig
$ComputerName = $env:COMPUTERNAME

$dbenv = ($Tags | Where-Object { $_.Key -eq "oasys-national-reporting-environment" }).Value
$bodsSecretName  = "/ec2/onr-bods/$dbenv/passwords"

$serviceUserPlainTextPassword = Get-SecretValue -SecretId $bodsSecretName -SecretKey $($Config.serviceUser)
$serviceUserPassword = ConvertTo-SecureString -String $serviceUserPlainTextPassword -AsPlainText -Force

New-ModPlatformADUser -Name $($Config.serviceUser) -Path $($Config.serviceUserPath) -Description $($Config.serviceUserDescription) -accountPassword $serviceUserPassword -ModPlatformADCredential $ADCredential

Enable-PSRemoting -Force

# Use admin credentials to add the service user to the Remote Desktop Users group
$ADAdminCredential = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig -ModPlatformADSecret $ADSecret

$serviceUser = "$($Config.domain)\$($Config.serviceUser)"
Write-Host "Adding $serviceUser to Remote Desktop Users group on $ComputerName"

Invoke-Command -ComputerName $ComputerName -Credential $ADAdminCredential -ScriptBlock {
   param($serviceUser)
   #Add the service user to the Remote Desktop Users group locally, if this isn't enough change to -Group Administrators
   Add-LocalGroupMember -Group "Remote Desktop Users" -Member $serviceUser
} -ArgumentList $serviceUser
# }}}

# {{{ prepare assets
New-Item -ItemType Directory -Path $WorkingDirectory -Force
New-Item -ItemType Directory -Path $AppDirectory -Force

Set-Location -Path $WorkingDirectory
Get-Installer -Key $Config.OracleClientS3File -Destination (".\" + $Config.OracleClientS3File)
Get-Installer -Key $Config.IPSS3File -Destination (".\" + $Config.IPSS3File)
Get-Installer -Key $Config.DataServicesS3File -Destination (".\" + $Config.DataServicesS3File)

Expand-Archive ( ".\" + $Config.OracleClientS3File) -Destination ".\OracleClient"
Expand-Archive ( ".\" + $Config.IPSS3File) -Destination ".\IPS"
# }}}

# {{{ Install Oracle Client
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

# Install Oracle Client silent install
$OracleClientInstallParams = @{
    FilePath         = "$WorkingDirectory\OracleClient\client\setup.exe"
    WorkingDirectory = "$WorkingDirectory\OracleClient\client"
    ArgumentList     = "-silent -noconfig -nowait -responseFile $WorkingDirectory\OracleClient\client\client_install.rsp"
    Wait             = $true
    NoNewWindow      = $true
}

Start-Process @OracleClientInstallParams

# Copy tnsnames.ora file to correct location
Copy-Item -Path "$ConfigurationManagementRepo\powershell\Configs\$($Config.tnsorafile)" -Destination "$($Config.ORACLE_HOME)\network\admin\tnsnames.ora" -Force

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

# {{{ install IPS
$Tags = Get-InstanceTags

# set Secret Names based on environment
$dbenv = ($Tags | Where-Object { $_.Key -eq "oasys-national-reporting-environment" }).Value
$siaNodeName = (($Tags | Where-Object { $_.Key -eq "Name" }).Value).Replace("-", "").ToUpper() # cannot contain hyphens
$bodsSecretName  = "/ec2/onr-bods/$dbenv/passwords"
$sysDbSecretName = "/oracle/database/$($Config.sysDbName)/passwords"
$audDbSecretName = "/oracle/database/$($Config.audDbName)/passwords"

# Get secret values, silently continue if they don't exist
$onr_system_owner = Get-SecretValue -SecretId $sysDbSecretName -SecretKey "onr_system_owner" -ErrorAction SilentlyContinue
$onr_audit_owner = Get-SecretValue -SecretId $audDbSecretName -SecretKey "onr_audit_owner" -ErrorAction SilentlyContinue
$bods_cluster_key = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_cluster_key" -ErrorAction SilentlyContinue
$bods_admin_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_admin_password" -ErrorAction SilentlyContinue
$bods_subversion_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_subversion_password" -ErrorAction SilentlyContinue
$product_key = Get-SecretValue -SecretId $bodsSecretName -SecretKey "product_key" -ErrorAction SilentlyContinue

# Create response file for IPS silent install
$ipsResponseFileContentCommon = @"
### Choose to integrate Introscope Enterprise Manager: integrate or nointegrate
chooseintroscopeintegration=nointegrate
### Choose to integrate Solution Manager Diagnostics (SMD) Agent: integrate or nointegrate
choosesmdintegration=nointegrate
### CMS cluster key
clusterkey=$bods_cluster_key
### CMS administrator password
cmspassword=$bods_admin_password
### CMS connection port
cmsport=6400
### Existing auditing DB password
existingauditingdbpassword=$onr_audit_owner
### Existing auditing DB server
existingauditingdbserver=$($Config.audDbName)
### Existing auditing DB user name
existingauditingdbuser=onr_audit_owner
### Existing CMS DB password
existingcmsdbpassword=$onr_system_owner
### Existing CMS DB reset flag: 0 or 1 where 1 means don't reset <<<<<<-- check this
existingcmsdbreset=1
### Existing CMS DB server
existingcmsdbserver=$($Config.sysDbName)
### Existing CMS DB user name
existingcmsdbuser=onr_system_owner
### Installation Directory
installdir=E:\SAP BusinessObjects\
### Choose install type: default, custom, webtier
installtype=custom
### LCM server name
lcmname=LCM_repository
### LCM password
lcmpassword=$bods_subversion_password
### LCM port
lcmport=3690
### LCM user name
lcmusername=LCM
### Choose install mode: new, expand where new == first instance of the installation
neworexpandinstall=new
### Product Keycode
productkey=$product_key
### Language Packs Selected to Install
selectedlanguagepacks=en
### Setup UI Language
setupuilanguage=en
### SIA node name
sianame=$siaNodeName
### SIA connector port
siaport=6410
### Tomcat connection port
tomcatconnectionport=28080
### Tomcat redirect port
tomcatredirectport=8443
### Tomcat shutdown port
tomcatshutdownport=8005
### Auditing Database Type
usingauditdbtype=oracle
### CMS Database Type
usingcmsdbtype=oracle
### Features to install
features=JavaWebApps1,CMC.Monitoring,LCM,IntegratedTomcat,CMC.AccessLevels,CMC.Applications,CMC.Audit,CMC.Authentication,CMC.Calendars,CMC.Categories,CMC.CryptographicKey,CMC.Events,CMC.Folders,CMC.Inboxes,CMC.Licenses,CMC.PersonalCategories,CMC.PersonalFolders,CMC.Servers,CMC.Sessions,CMC.Settings,CMC.TemporaryStorage,CMC.UsersAndGroups,CMC.QueryResults,CMC.InstanceManager,CMS,FRS,PlatformServers.AdaptiveProcessingServer,PlatformServers.AdaptiveJobServer,ClientAuditingProxyProcessingService,LCMProcessingServices,MonitoringProcessingService,SecurityTokenService,DestinationSchedulingService,ProgramSchedulingService,Subversion,UpgradeManager,AdminTools
"@

# Create response file for IPS expanded install
$ipsResponseFileContentExtendedNode = @"
### Choose install mode: new, expand where new == first instance of the installation
neworexpandinstall=expand
### Install a new LCM or use an existing LCM
neworexistinglcm=expand
### CMS cluster key
clusterkey=$bods_cluster_key
### CMS administrator password
cmspassword=$bods_admin_password
### CMS connection port
cmsport=6400
### Existing main cms node name
cmsname=$($Config.cmsMainNode)
### Product Keycode
productkey=$product_key
### SIA node name
sianame=$siaNodeName
### SIA connector port
siaport=6410
### Language Packs Selected to Install
selectedlanguagepacks=en
### Setup UI Language
setupuilanguage=en
### Installation Directory
installdir=E:\SAP BusinessObjects\
### Choose install type: default, custom, webtier
installtype=custom
### Choose to integrate Introscope Enterprise Manager: integrate or nointegrate
chooseintroscopeintegration=nointegrate
### Choose to integrate Solution Manager Diagnostics (SMD) Agent: integrate or nointegrate
choosesmdintegration=nointegrate
### Features to install
features=JavaWebApps1,CMC.Monitoring,LCM,IntegratedTomcat,CMC.AccessLevels,CMC.Applications,CMC.Audit,CMC.Authentication,CMC.Calendars,CMC.Categories,CMC.CryptographicKey,CMC.Events,CMC.Folders,CMC.Inboxes,CMC.Licenses,CMC.PersonalCategories,CMC.PersonalFolders,CMC.Servers,CMC.Sessions,CMC.Settings,CMC.TemporaryStorage,CMC.UsersAndGroups,CMC.QueryResults,CMC.InstanceManager,CMS,FRS,PlatformServers.AdaptiveProcessingServer,PlatformServers.AdaptiveJobServer,ClientAuditingProxyProcessingService,LCMProcessingServices,MonitoringProcessingService,SecurityTokenService,DestinationSchedulingService,ProgramSchedulingService,Subversion,UpgradeManager,AdminTools
"@

# TODO: supply password values to argument list OR remove the reponse file after it's been used

$instanceName = ($Tags | Where-Object { $_.Key -eq "Name" }).Value

if ($instanceName -eq $($Config.cmsMainNode)) {
    $ipsResponseFileContentCommon | Out-File -FilePath "$WorkingDirectory\IPS\DATA_UNITS\IPS_win\ips_install.rsp" -Force -Encoding ascii
} elseif ($instanceName -eq $($Config.cmsExtendedNode)) {
    $ipsResponseFileContentExtendedNode | Out-File -FilePath "$WorkingDirectory\IPS\DATA_UNITS\IPS_win\ips_install.rsp" -Force -Encoding ascii
} else {
    Write-Output "Unknown node type, cannot create response file"
    exit 1
}

$ipsInstallParams = @{
    FilePath = "$WorkingDirectory\IPS\DATA_UNITS\\IPS_win\setup.exe"
    WorkingDirectory = "$WorkingDirectory\IPS\DATA_UNITS\IPS_win"
    ArgumentList = "-r $WorkingDirectory\IPS\DATA_UNITS\IPS_win\ips_install.rsp"
    Wait = $true
    NoNewWindow = $true
}

# debugging
$ipsInstallParams | Out-File -FilePath "$WorkingDirectory\IPS\DATA_UNITS\IPS_win\ips_install_params.txt" -Force

Clear-PendingFileRenameOperations

# Disable for now during testing
# Start-Process @ipsInstallParams

# }}} end install IPS

# {{{ install Data Services
[Environment]::SetEnvironmentVariable("LINK_DIR", $Config.LINK_DIR, [System.EnvironmentVariableTarget]::Machine)

if (-NOT(Test-Path "F:\BODS_COMMON_DIR")) {
    Write-Output "Creating F:\BODS_COMMON_DIR"
    New-Item -ItemType Directory -Path "F:\BODS_COMMON_DIR"
}
[Environment]::SetEnvironmentVariable("DS_COMMON_DIR", "F:\BODS_COMMON_DIR", [System.EnvironmentVariableTarget]::Machine)
#
$data_services_product_key = Get-SecretValue -SecretId $bodsSecretName -SecretKey "data_services_product_key" -ErrorAction SilentlyContinue
$data_services_user_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "$($Config.serviceUser)" -ErrorAction SilentlyContinue

$dataServicesResponsePrimary = @"
### #property.CMSAUTHENTICATION.description#
cmsauthentication=secEnterprise
### CMS administrator password
cmspassword=$bods_admin_password
### #property.CMSUSERNAME.description#
cmsusername=Administrator
### #property.CMSAuthMode.description#
dscmsauth=secEnterprise
### #property.CMSEnabledSSL.description#
dscmsenablessl=0
### CMS administrator password
dscmspassword=$bods_admin_password
### #property.CMSServerPort.description#
dscmsport=6400
### #property.CMSServerName.description#
dscmssystem=$($Config.cmsMainNode)
### #property.CMSUser.description#
dscmsuser=Administrator
### #property.DSCommonDir.description#
dscommondir=F:\BODS_COMMON_DIR\
### #property.DSConfigCMSSelection.description#
dsconfigcmsselection=install
### #property.DSConfigMergeSelection.description#
dsconfigmergeselection=skip
### #property.DSExistingDSConfigFile.description#
dsexistingdsconfigfile=
### #property.DSInstallTypeSelection.description#
dsinstalltypeselection=Custom
### #property.DSLocalCMS.description#
dslocalcms=true
### #property.DSLoginInfoAccountSelection.description#
dslogininfoaccountselection=this
### #property.DSLoginInfoThisUser.description#
dslogininfothisuser=$($Config.Domain)\$($Config.serviceUser)
### #property.DSLoginInfoThisPassword.description#
dslogininfothispassword=$data_services_user_password
### Installation folder for SAP products
installdir=E:\SAP BusinessObjects\
### #property.IsCommonDirChanged.description#
iscommondirchanged=1
### #property.MasterCmsName.description#
mastercmsname=$($Config.cmsMainNode)
### #property.MasterCmsPort.description#
mastercmsport=6400
### Keycode for the product.
productkey=$data_services_product_key
### *** property.SelectedLanguagePacks.description ***
selectedlanguagepacks=en
### Available features
features=DataServicesJobServer,DataServicesAccessServer,DataServicesServer,DataServicesDesigner,DataServicesClient,DataServicesManagementConsole,DataServicesEIMServices,DataServicesMessageClient,DataServicesDataDirect,DataServicesDocumentation
"@

$dataServicesResponsePrimary | Out-File -FilePath "$WorkingDirectory\ds_install.rsp" -Force -Encoding ascii

$dataServicesInstallParams = @{
    FilePath = "$WorkingDirectory\$($Config.DataServicesS3File)"
    WorkingDirectory = $WorkingDirectory
    ArgumentList = "-r $WorkingDirectory\ds_install.rsp"
    Wait = $true
    NoNewWindow = $true
}

# Disable this for testing
# Start-Process @dataServicesInstallParams
# }}} End install Data Services

# {{{ login text
# Apply to all environments that aren't on the domain
$ErrorActionPreference = "Stop"
Write-Output "Add Legal Notice"

if (-NOT (Test-Path $Config.RegistryPath)) {
    Write-Output " - Registry path does not exist, creating"
    New-Item -Path $Config.RegistryPath -Force | Out-Null
}

$RegistryPath = $Config.RegistryPath
$LegalNoticeCaption = $Config.LegalNoticeCaption
$LegalNoticeText = $Config.LegalNoticeText

Write-Output " - Set Legal Notice Caption"
New-ItemProperty -Path $RegistryPath -Name LegalNoticeCaption -Value $LegalNoticeCaption -PropertyType String -Force

Write-Output " - Set Legal Notice Text"
New-ItemProperty -Path $RegistryPath -Name LegalNoticeText -Value $LegalNoticeText -PropertyType String -Force
# }}}
