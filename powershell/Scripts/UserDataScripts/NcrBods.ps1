$GlobalConfig = @{
    "all"                                    = @{
        "WindowsClientS3Bucket"      = "mod-platform-image-artefact-bucket20230203091453221500000001"
        "WindowsClientS3Folder"      = "hmpps/ncr"
        "Oracle19c64bitClientS3File" = "WINDOWS.X64_193000_client.zip"
        "ORACLE_19C_HOME"            = "E:\app\oracle\product\19.0.0\client_1"
        "ORACLE_BASE"                = "E:\app\oracle"
        "IPSS3File"                  = "51054521.ZIP" # Information Platform Services 4.2 SP8 Patch 1
        "DataServicesS3File"         = "51054517_4.ZIP" # Data Services 4.2 SP 14 as per Azure machines for NCR BODS
        "LINK_DIR"                   = "E:\SAP BusinessObjects\Data Services"
        "BIP_INSTALL_DIR"            = "E:\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0"
        "RegistryPath"               = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon"
        "LegalNoticeCaption"         = "IMPORTANT"
        "LegalNoticeText"            = "This system is restricted to authorized users only. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information"
    }
    "nomis-combined-reporting-development"   = @{

    }
    "nomis-combined-reporting-test"          = @{
        # "sysDbName"       = ""
        # "audDbName"       = ""
        "tnsorafile"             = "NCR\tnsnames_T1_BODS.ora"
        "cmsPrimaryNode"         = "t1-ncr-bods-1"
        # "cmsPrimaryNode"     = "t1-tst-bods-asg" # Use this value when testing
        # "cmsSecondaryNode" = "t1-ncr-bods-2"
        # "cmsPrimaryNodeHostname" = "" ADD MANUALLY AFTER cmsPrimaryNode DEPLOYED
        "serviceUser"            = "svc_nart"
        "serviceUserPath"        = "OU=Service,OU=Users,OU=NOMS RBAC,DC=AZURE,DC=NOMS,DC=ROOT"
        "nartComputersOU"        = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
        "serviceUserDescription" = "NART service user for AWS in AZURE domain"
        "domain"                 = "AZURE"
    }
    "nomis-combined-reporting-preproduction" = @{
        # "sysDbName"       = ""
        # "audDbName"       = ""
        "tnsorafile"             = "NCR\tnsnames_PP_BODS.ora"
        "cmsPrimaryNode"         = "pp-ncr-bods-1"
        # "cmsSecondaryNode" = "pp-ncr-bods-2"
        # "cmsPrimaryNodeHostname" = "" ADD MANUALLY AFTER cmsPrimaryNode DEPLOYED
        "serviceUser"            = "svc_nart"
        "serviceUserPath"        = "OU=SERVICE_ACCOUNTS,OU=RBAC,DC=AZURE,DC=HMPP,DC=ROOT"
        "nartComputersOU"        = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT"
        "serviceUserDescription" = "NART service user for AWS in HMPP domain"
        "domain"                 = "HMPP"
    }
    "nomis-combined-reporting-production"    = @{
        "domain" = "HMPP"
    }
}

# {{{ functions

function Test-DbCredentials {
    [CmdletBinding()]
    param (
        [Parameter()]
        [hashtable]
        $Config
    )

    # Check database credentials BEFORE installer runs
    $typePath = "E:\app\oracle\product\19.0.0\client_1\ODP.NET\bin\4\Oracle.DataAccess.dll"

    $sysDbSecretName = "/oracle/database/$($Config.sysDbName)/passwords"
    $audDbSecretName = "/oracle/database/$($Config.audDbName)/passwords"

    # Get secret values, silently continue if they don't exist
    $bods_ips_system_owner = Get-SecretValue -SecretId $sysDbSecretName -SecretKey "bods_ips_system_owner" -ErrorAction SilentlyContinue
    $bods_ips_audit_owner = Get-SecretValue -SecretId $audDbSecretName -SecretKey "bods_ips_audit_owner" -ErrorAction SilentlyContinue

    # Define an array of database configurations
    $dbConfigs = @(
        @{
            Name     = "$($Config.sysDbName)"
            Username = "bods_ips_system_owner"
            Password = $bods_ips_system_owner
        },
        @{
            Name     = "$($Config.audDbName)"
            Username = "bods_ips_audit_owner"
            Password = $bods_ips_audit_owner
        }
    )

    # Loop through each database configuration
    foreach ($db in $dbConfigs) {
        $securePassword = ConvertTo-SecureString -String $db.Password -AsPlainText -Force
        $return = Test-DatabaseConnection -typePath $typePath -tnsName $db.Name -username $db.Username -securePassword $securePassword
        if ($return -ne 0) {
            Write-Host "Connection to $($db.Name) failed. Exiting."
            exit 1
        }
        Write-Host "Connection to $($db.Name) successful."
    }

    Write-Host "All database connections successful."

}

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

function Test-DatabaseConnection {
    param (
        [Parameter(Mandatory = $true)]
        [String]$typePath,
        [Parameter(Mandatory = $true)]
        [String]$tnsName,
        [Parameter(Mandatory = $true)]
        [String]$username,
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$securePassword
    )

    Add-Type -Path $typePath

    # Convert SecureString to plain text safely
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    # Create connection string
    $connectionString = "User Id=$username;Password=$plainPassword;Data Source=$tnsName"
    $connection = New-Object Oracle.DataAccess.Client.OracleConnection($connectionString)

    try {
        # Test connection
        $connection.Open()
        Write-Host "Connection successful!"
        return 0
    }
    catch {
        Write-Host "Connection failed: $($_.Exception.Message)"
        return 1
    }
    finally {
        if ($connection -and $connection.State -eq 'Open') {
            $connection.Close()
        }
        # Clear sensitive data
        if ($BSTR) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }
        $plainPassword = $null
        $connectionString = $null
    }
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

function Install-IPS {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    if (Test-Path "$WorkingDirectory\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0") {
        Write-Output "IPS is already installed"
        return
    }

    $Tags = Get-InstanceTags

    Get-Installer -Key $Config.IPSS3File -Destination (".\" + $Config.IPSS3File)

    Expand-Archive ( ".\" + $Config.IPSS3File) -Destination ".\IPS"

    # set Secret Names based on environment
    $dbenv = ($Tags | Where-Object { $_.Key -eq "nomis-combined-reporting-environment" }).Value
    $siaNodeName = (($Tags | Where-Object { $_.Key -eq "Name" }).Value).Replace("-", "").ToUpper() # cannot contain hyphens
    $bodsSecretName = "/sap/bods/$dbenv/passwords"
    $bodsConfigName = "/sap/bods/$dbenv/config"
    $sysDbSecretName = "/oracle/database/$($Config.sysDbName)/passwords"
    $audDbSecretName = "/oracle/database/$($Config.audDbName)/passwords"

    # Get secret values from relevant db's secrets
    $bods_ips_system_owner = Get-SecretValue -SecretId $sysDbSecretName -SecretKey "bods_ips_system_owner" -ErrorAction SilentlyContinue
    $bods_ips_audit_owner = Get-SecretValue -SecretId $audDbSecretName -SecretKey "bods_ips_audit_owner" -ErrorAction SilentlyContinue

    # /sap/bods/$dbenv/passwords values
    $bods_admin_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_admin_password" -ErrorAction SilentlyContinue
    $bods_subversion_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_subversion_password" -ErrorAction SilentlyContinue

    # /sap/bods/$dbenv/config values
    $bods_cluster_key = Get-SecretValue -SecretId $bodsConfigName -SecretKey "bods_cluster_key" -ErrorAction SilentlyContinue
    $ips_product_key = Get-SecretValue -SecretId $bodsConfigName -SecretKey "ips_product_key" -ErrorAction SilentlyContinue

    # Create response file for IPS silent install
    $ipsResponseFilePrimary = @"
### Choose to integrate Introscope Enterprise Manager: integrate or nointegrate
chooseintroscopeintegration=nointegrate
### Choose to integrate Solution Manager Diagnostics (SMD) Agent: integrate or nointegrate
choosesmdintegration=nointegrate
### CMS cluster key
clusterkey=$bods_cluster_key
### CMS administrator password
# cmspassword=**** bods_admin_password value supplied directly via silent install params
### CMS connection port
cmsport=6400
### Existing auditing DB password
# existingauditingdbpassword=**** bods_ips_audit_owner value supplied directly via silent install params
### Existing auditing DB server
existingauditingdbserver=$($Config.audDbName)
### Existing auditing DB user name
existingauditingdbuser=bods_ips_audit_owner
### Existing CMS DB password
# existingcmsdbpassword=**** bods_ips_system_owner value supplied directly via silent install params
### Existing CMS DB reset flag: 0 or 1 where 1 means don't reset <<<<<<-- check this
existingcmsdbreset=1
### Existing CMS DB server
existingcmsdbserver=$($Config.sysDbName)
### Existing CMS DB user name
existingcmsdbuser=bods_ips_system_owner
### Installation Directory
installdir=E:\SAP BusinessObjects\
### Choose install type: default, custom, webtier
installtype=custom
### LCM server name
lcmname=LCM_repository
### LCM password
# lcmpassword=**** bods_subversion_password value supplied directly via silent install params
### LCM port
lcmport=3690
### LCM user name
lcmusername=LCM
### Choose install mode: new, expand where new == first instance of the installation
neworexpandinstall=new
### Product Keycode
productkey=$ips_product_key
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
    $ipsResponseFileSecondary = @"
### Choose to integrate Introscope Enterprise Manager: integrate or nointegrate
chooseintroscopeintegration=nointegrate
### Choose to integrate Solution Manager Diagnostics (SMD) Agent: integrate or nointegrate
choosesmdintegration=nointegrate
### CMS cluster key
clusterkey=$bods_cluster_key
### CMS connection port
cmsport=6400
### Choose to start servers after install: 0 or 1
enableservers=0
### Existing CMS DB password
# existingcmsdbpassword=**** bods_ips_system_owner value in silent install params
### Existing CMS DB reset flag: 0 or 1
existingcmsdbreset=0
### Existing CMS DB server
existingcmsdbserver=$($Config.sysDbName)
### Existing CMS DB user name
existingcmsdbuser=bods_ips_system_owner
### Installation Directory
installdir=E:\SAP BusinessObjects\
### Choose install type: default, custom, webtier
installtype=custom
### LCM server name
lcmname=LCM_repository
### LCM password
# lcmpassword=**** bods_subversion_password value in silent install params
### LCM port
lcmport=3690
### LCM user name
lcmusername=LCM
### Choose install mode: new, expand
neworexpandinstall=expand
### Product Keycode
productkey=$ips_product_key
### Remote CMS administrator name
remotecmsadminname=Administrator
### Remote CMS administrator password
# remotecmsadminpassword=**** bods_admin_password value in silent install params
### Remote CMS name
remotecmsname=$($Config.cmsPrimaryNodeHostname).$domainName
### Remote CMS port
remotecmsport=6400
### Language Packs Selected to Install
selectedlanguagepacks=en
### Setup UI Language
setupuilanguage=en
### SIA node name
sianame=$remoteSiaName
### SIA connector port
siaport=6410
### Tomcat connection port
tomcatconnectionport=28080
### Tomcat redirect port
tomcatredirectport=8443
### Tomcat shutdown port
tomcatshutdownport=8005
### CMS Database Type
usingcmsdbtype=oracle
### Features to install
features=JavaWebApps1,CMC.Monitoring,LCM,IntegratedTomcat,CMC.AccessLevels,CMC.Applications,CMC.Audit,CMC.Authentication,CMC.Calendars,CMC.Categories,CMC.CryptographicKey,CMC.Events,CMC.Folders,CMC.Inboxes,CMC.Licenses,CMC.PersonalCategories,CMC.PersonalFolders,CMC.Servers,CMC.Sessions,CMC.Settings,CMC.TemporaryStorage,CMC.UsersAndGroups,CMC.QueryResults,CMC.InstanceManager,CMS,FRS,PlatformServers.AdaptiveProcessingServer,PlatformServers.AdaptiveJobServer,ClientAuditingProxyProcessingService,LCMProcessingServices,MonitoringProcessingService,SecurityTokenService,DestinationSchedulingService,ProgramSchedulingService,Subversion,UpgradeManager,AdminTools
"@


    $instanceName = ($Tags | Where-Object { $_.Key -eq "Name" }).Value
    $ipsInstallIni = "$WorkingDirectory\IPS\DATA_UNITS\IPS_win\ips_install.ini"

    if ($instanceName -eq $($Config.cmsPrimaryNode)) {
        $ipsResponseFilePrimary | Out-File -FilePath "$ipsInstallIni" -Force -Encoding ascii
    }
    elseif ($instanceName -eq $($Config.cmsSecondaryNode)) {
        $ipsResponseFileSecondary | Out-File -FilePath "$ipsInstallIni" -Force -Encoding ascii
    }
    else {
        Write-Output "Unknown node type, cannot create response file"
        exit 1
    }

    Clear-PendingFileRenameOperations

    $setupExe = "$WorkingDirectory\IPS\DATA_UNITS\IPS_win\setup.exe"

    if (-NOT(Test-Path $setupExe)) {
        Write-Host "IPS setup.exe not found at $($setupExe)"
        exit 1
    }

    if (-NOT(Test-Path $ipsInstallIni)) {
        Write-Host "IPS response file not found at $ipsInstallIni"
        exit 1
    }

    $logFile = "$WorkingDirectory\IPS\DATA_UNITS\IPS_win\install_ips_sp.log"
    New-Item -Type File -Path $logFile -Force | Out-Null

    # add Oracle client path to the powershell session
    $env:Path += ";E:\app\oracle\product\19.0.0\client_1\bin"

    $env:Path -split ";" | ForEach-Object {
        Write-Host $_
    }

    Write-Host "Starting IPS installer at $(Get-Date)"

    try {
        "Starting IPS installer at $(Get-Date)" | Out-File -FilePath $logFile -Append
        if ($instanceName -eq $($Config.cmsPrimaryNode)) {
            # $process = Start-Process -FilePath "E:\Software\IPS\DATA_UNITS\IPS_win\setup.exe" -ArgumentList '/wait', '-r E:\Software\IPS\DATA_UNITS\IPS_win\ips_install.ini', "cmspassword=$bods_admin_password", "existingauditingdbpassword=$bods_ips_audit_owner", "existingcmsdbpassword=$bods_ips_system_owner", "lcmpassword=$bods_subversion_password" -Wait -NoNewWindow -Verbose -PassThru
        }
        elseif ($instanceName -eq $($Config.cmsSecondaryNode)) {
            # $process = Start-Process -FilePath "E:\Software\IPS\DATA_UNITS\IPS_win\setup.exe" -ArgumentList '/wait', '-r E:\Software\IPS\DATA_UNITS\IPS_win\ips_install.ini', "remotecmsadminpassword=$bods_admin_password", "existingcmsdbpassword=$bods_ips_system_owner", "lcmpassword=$bods_subversion_password" -Wait -NoNewWindow -Verbose -PassThru
        }
        else {
            Write-Output "Unknown node type, cannot start installer"
            exit 1
        }
        $installProcessId = $process.Id
        "Initial process is $installProcessId at $(Get-Date)" | Out-File -FilePath $logFile -Append
        "Stopped IPS installer at $(Get-Date)" | Out-File -FilePath $logFile -Append
    } 
    catch {
        $exception = $_.Exception
        "Failed to start installer at $(Get-Date)" | Out-File -FilePath $logFile -Append
        "Exception Message: $($exception.Message)" | OUt-File -FilePath $logFile -Append
        if ($exception.InnerException) {
            "Inner Exception Message: $($exception.InnerException.Message)" | Out-File -FilePath $logFile -Append
        }
    }
}

function Install-DataServices {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    if (Get-Package | Where-Object { $_.Name -Like "SAP Data Services*" }) {
        Write-Output "Data Services is already installed"
        return
    }

    Get-Installer -Key $Config.DataServicesS3File -Destination (".\" + $Config.DataServicesS3File)

    Expand-Archive -Path (".\" + $Config.DataServicesS3File) -Destination ".\DataServices"

    [Environment]::SetEnvironmentVariable("LINK_DIR", $Config.LINK_DIR, [System.EnvironmentVariableTarget]::Machine)

    if (-NOT(Test-Path "F:\BODS_COMMON_DIR")) {
        Write-Output "Creating F:\BODS_COMMON_DIR"
        New-Item -ItemType Directory -Path "F:\BODS_COMMON_DIR"
    }
    [Environment]::SetEnvironmentVariable("DS_COMMON_DIR", "F:\BODS_COMMON_DIR", [System.EnvironmentVariableTarget]::Machine)

    # set Secret Names based on environment
    $Tags = Get-InstanceTags
    $dbenv = ($Tags | Where-Object { $_.Key -eq "nomis-combined-reporting-environment" }).Value
    $bodsSecretName = "/sap/bods/$dbenv/passwords"
    $bodsConfigName = "/sap/bods/$dbenv/config"

    # passwords from /sap/bods/$dbenv/passwords
    $service_user_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "svc_nart" -ErrorAction SilentlyContinue
    $bods_admin_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_admin_password" -ErrorAction SilentlyContinue

    # config values from /sap/bods/$dbenv/config
    $data_services_product_key = Get-SecretValue -SecretId $bodsConfigName -SecretKey "data_services_product_key" -ErrorAction SilentlyContinue

    $dataServicesResponsePrimary = @"
### #property.CMSAUTHENTICATION.description#
cmsauthentication=secEnterprise
### CMS administrator password
# cmspassword=**** bods_admin_password value supplied directly via silent install params
### #property.CMSUSERNAME.description#
cmsusername=Administrator
### #property.CMSEnabledSSL.description#
dscmsenablessl=0
### CMS administrator password
# dscmspassword=**** bods_admin_password value supplied directly via silent install params
### #property.CMSServerPort.description#
dscmsport=6400
### #property.CMSServerName.description#
dscmssystem=$($env:COMPUTERNAME)
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
# dslogininfothispassword=**** service_user_password value supplied directly via silent install params
### Installation folder for SAP products
installdir=E:\SAP BusinessObjects\
### #property.IsCommonDirChanged.description#
iscommondirchanged=1
### #property.MasterCmsName.description#
mastercmsname=$($env:COMPUTERNAME)
### #property.MasterCmsPort.description#
mastercmsport=6400
### Keycode for the product.
productkey=$data_services_product_key
### *** property.SelectedLanguagePacks.description ***
selectedlanguagepacks=en
### Available features
features=DataServicesJobServer,DataServicesAccessServer,DataServicesServer,DataServicesDesigner,DataServicesClient,DataServicesManagementConsole,DataServicesEIMServices,DataServicesMessageClient,DataServicesDataDirect,DataServicesDocumentation
"@

    $domainName = ($Tags | Where-Object { $_.Key -eq "domain-name" }).Value

    $dataServicesResponseSecondary = @"
### #property.CMSAUTHENTICATION.description#
cmsauthentication=secEnterprise
### CMS administrator password
# cmspassword=**** bods_admin_password value in silent install params
### #property.CMSUSERNAME.description#
cmsusername=Administrator
### #property.CMSAuthMode.description#
dscmsauth=secEnterprise
### #property.CMSEnabledSSL.description#
dscmsenablessl=0
### CMS administrator password
# dscmspassword=**** bods_admin_password value in silent install params
### #property.CMSServerPort.description#
dscmsport=6400
### #property.CMSServerName.description#
dscmssystem=$($Config.cmsPrimaryNodeHostname).$domainName
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
dslocalcms=false
### #property.DSLoginInfoAccountSelection.description#
dslogininfoaccountselection=this
### #property.DSLoginInfoThisPassword.description#
# dslogininfothispassword=**** service_user_password value in silent install params
### #property.DSLoginInfoThisUser.description#
dslogininfothisuser=$($Config.Domain)\$($Config.serviceUser)
### Installation folder for SAP products
installdir=E:\SAP BusinessObjects\
### #property.IsCommonDirChanged.description#
iscommondirchanged=1
### #property.MasterCmsName.description#
mastercmsname=$($Config.cmsPrimaryNodeHostname).$domainName
### #property.MasterCmsPort.description#
mastercmsport=6400
### Keycode for the product.
productkey=$data_services_product_key
### *** property.SelectedLanguagePacks.description ***
selectedlanguagepacks=en
### Available features
features=DataServicesJobServer,DataServicesAccessServer,DataServicesServer,DataServicesDesigner,DataServicesClient,DataServicesManagementConsole,DataServicesEIMServices,DataServicesMessageClient,DataServicesDataDirect,DataServicesDocumentation
"@

    $instanceName = ($Tags | Where-Object { $_.Key -eq "Name" }).Value
    $dsInstallIni = "$WorkingDirectory\ds_install.ini"

    if ($instanceName -eq $Config.cmsPrimaryNode) {
        $dataServicesResponsePrimary | Out-File -FilePath $dsInstallIni -Force -Encoding ascii
    }
    elseif ($instanceName -eq $Config.cmsSecondaryNode) {
        $dataServicesResponseSecondary | Out-File -FilePath $dsInstallIni -Force -Encoding ascii
    }
    else {
        Write-Output "Unknown node type, cannot create response file"
        exit 1
    }

    $dataServicesInstallParams = @{
        FilePath     = "$WorkingDirectory\$($Config.DataServicesS3File)\DataServices\setup.exe"
        ArgumentList = "-q", "-r", "$dsInstallIni", "cmspassword=$bods_admin_password", "dscmspassword=$bods_admin_password", "dslogininfothispassword=$service_user_password"
        Wait         = $true
        NoNewWindow  = $true
    }

    # Install Data Services
    # Start-Process @dataServicesInstallParams

    # }}} End install Data Services

    # {{{ Post install steps for Data Services, configure JDBC driver
    $jdbcDriverPath = "$($Config.ORACLE_19C_HOME)\jdbc\lib\ojdbc8.jar"
    $destinations = @(
        "$($Config.LINK_DIR)\ext\lib",
        "$($Config.BIP_INSTALL_DIR)\java\lib\im\oracle" #, # uncomment comma and line below if using Data Quality reports
        # "$($Config.BIP_INSTALL_DIR)\warfiles\webapps\DataServices\WEB-INF\lib" # Only needed if using Data Quality reports
    )

    if (Test-Path $jdbcDriverPath) {
        foreach ($destination in $destinations) {
            if (Test-Path $destination) {
                Write-Output "Copying JDBC driver to $destination"
                Copy-Item -Path $jdbcDriverPath -Destination $destination
            }
            else {
                Write-Output "Destination $destination does not exist, skipping"
            }
        }
    }
    else {
        Write-Output "JDBC driver not found at $jdbcDriverPath"
        exit 1
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

function Set-LoginText {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
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
}
# }}}

$ErrorActionPreference = "Stop"
# {{{ Prep the server for installation
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

$WorkingDirectory = "E:\Software"
$AppDirectory = "E:\App"

$ModulesRepo = Join-Path $PSScriptRoot '..\..\Modules'

# {{{ join domain if domain-name tag is set
# Join domain and reboot is needed before installers run
# Add $ModulesRepo to the PSModulePath in Server 2012 R2 otherwise it can't find it
$env:PSModulePath = "$ModulesRepo;$env:PSModulePath"

# {{{ join domain if domain-name tag is set
# Join domain and reboot is needed before installers run
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
# }}}

# {{{ prepare assets
$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Path $WorkingDirectory -Force
New-Item -ItemType Directory -Path $AppDirectory -Force

Set-Location -Path $WorkingDirectory

# IMPORTANT: Response files for these versions need checking first to ensure they are correct. Need to sort out tnsorafiles and have a database target to test against, then uncomment the lines below BUT not install IPS/DataServices. Need to CREATE THE SECRETS FIRST (see docs) as well as manually run the installers with -w 'E:\Software\responsefile.ini' to check the values are correct. Then make any install file changes before running everything.

Install-Oracle19cClient -Config $Config
# IMPORTANT: NCR tnsorafiles are not defined for any environment yet
# New-TnsOraFile -Config $Config
# IMPORTANT: Requires a database target to test against
# Test-DbCredentials -Config $Config
# IMPORTANT: currently only downloads the IPS installer, does not install it
Install-IPS -Config $Config
# IMPORTANT: currently only downloads the Data Services installer, does not install it 
Install-DataServices -Config $Config
Set-LoginText -Config $Config
