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

    $ApplicationTag = ($Tags.Tags | Where-Object { $_.Key -eq "application" }).Value
    
    # FIXME: This won't work in a sustainable way - no longer used
    # $dbenvTag = ($Tags.Tags | Where-Object { $_.Key -eq "delius-mis-environment" }).Value

    $nameTag = ($Tags.Tags | Where-Object { $_.Key -eq "Name" }).Value

    $domainName = ($Tags.Tags | Where-Object { $_.Key -eq "domain-name" }).Value

    $serverType = ($Tags.Tags | Where-Object { $_.Key -eq "server-type" }).Value

    if ($ApplicationTag -eq "oasys-national-reporting") {
        $configPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Configs\ONR\onr_config.ps1"
    }
    elseif ($ApplicationTag -eq "nomis-combined-reporting") {
        $configPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Configs\NCR\ncr_config.ps1"
    }
    else { # used for MISDis, needs retrofitting to NCR and ONR to remove this if else entirely
        Write-Host "Using Server-Type tag to determine config path"
        $configPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Configs\$serverType\$($serverType)_config.ps1"
    }

    # dot source the config file containing $GlobalConfig
    . $configPath

    if (-not $GlobalConfig.Contains($EnvironmentNameTag)) {
        Write-Error "Unexpected environment-name tag value $EnvironmentNameTag"
    }

    $additionalConfig = @{
        application = $ApplicationTag
        # dbenv       = $dbenvTag
        Name        = $nameTag
        domainName  = $domainName
    }

    # Merge all config hashtables into one
    $mergedConfig = @{}
    $GlobalConfig.all.GetEnumerator() | ForEach-Object { $mergedConfig[$_.Key] = $_.Value }
    $GlobalConfig[$EnvironmentNameTag].GetEnumerator() | ForEach-Object { $mergedConfig[$_.Key] = $_.Value }
    $additionalConfig.GetEnumerator() | ForEach-Object { $mergedConfig[$_.Key] = $_.Value }
    return $mergedConfig
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

function Install-IPS {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # easier to fix here rather than do command substitution inside the install params
    $WorkingDirectory = $Config.WorkingDirectory

    if (Test-Path "$WorkingDirectory\BusinessObjects\SAP BusinessObjects Enterprise XI 4.0") {
        Write-Output "IPS is already installed"
        return
    }

    if (-not (Test-Path "$WorkingDirectory\IPS")) {
        Write-Output "Creating IPS directory at $WorkingDirectory\IPS"
        New-Item -Path "$WorkingDirectory\IPS" -ItemType Directory -Force
    }

    Get-Installer -Key $Config.IPSS3File -Destination "$WorkingDirectory\$($Config.IPSS3File)"

    # NOTE: unrar is used to extract the IPS installer, rather than have to manage the self extracting archive process. This is installed via AutoEC2LaunchV2 automation script in the modernisation-platform-environments repo

    unrar x -r -o+ -y "$WorkingDirectory\$($Config.IPSS3File)" "$WorkingDirectory\IPS"

    # TODO: FIXME: executable needs to be un-packed first. Cannot use Expand-Archive as it is an executable, not a zip file!!
    # Expand-Archive ( ".\" + $Config.IPSS3File) -Destination ".\IPS"

    # set Secret Names based on environment
    # $siaNodeName = $Config.SiaNodeName # FIXME: hard-coded in
    # $bodsSecretName = "/sap/bods/$($Config.dbenv)/passwords" # FIXME: secret buckets hardcoded below
    # $bodsConfigName = "/sap/bods/$($Config.dbenv)/config" # FIXME: secret buckets hardcoded below
    # $sysDbSecretName = "/oracle/database/$($Config.sysDbName)/passwords" # FIXME: check this works/is available format in MISDis environment - it's not...
    # $audDbSecretName = "/oracle/database/$($Config.audDbName)/passwords" # FIXME: check this works/is available format in MISDis environment - it's not...

    # Get secret values from relevant db's secrets
    # $bods_ips_system_owner = Get-SecretValue -SecretId $sysDbSecretName -SecretKey "bods_ips_system_owner" -ErrorAction SilentlyContinue
    $bods_ips_system_owner = Get-SecretValue -SecretId "delius-mis-dev-oracle-dsd-db-application-passwords" -SecretKey "dfi_mod_ipscms" -ErrorAction SilentlyContinue
    # $bods_ips_audit_owner = Get-SecretValue -SecretId $audDbSecretName -SecretKey "bods_ips_audit_owner" -ErrorAction SilentlyContinue
    $bods_ips_audit_owner = Get-SecretValue -SecretId "delius-mis-dev-oracle-dsd-db-application-passwords" -SecretKey "dfi_mod_ipsaud" -ErrorAction SilentlyContinue

    # /sap/bods/$dbenv/passwords values
    # NOT USED IN THIS INSTALL - replaced with bods_cluster_key
    # $bods_admin_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_admin_password" -ErrorAction SilentlyContinue
    # NOT USED IN THIS INSTALL
    # $bods_subversion_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_subversion_password" -ErrorAction SilentlyContinue

    # /sap/bods/$dbenv/config values - hardcoded for expediency - will need refactoring later
    $bods_cluster_key = Get-SecretValue -SecretId 'NDMIS_DFI_SERVICEACCOUNTS_DEV' -SecretKey "IPS_Administrator_LCMS_Administrator" -ErrorAction SilentlyContinue

    # $ips_product_key = Get-SecretValue -SecretId $bodsConfigName -SecretKey "ips_product_key" -ErrorAction SilentlyContinue
    $ips_product_key = Get-SecretValue -SecretId 'NDMIS_DFI_SERVICEACCOUNTS_DEV' -SecretKey "ips_product_key" -ErrorAction SilentlyContinue
    # HARDCODED for expediency, will need refactoring later # FIXME:
    # $cms_primary_node_hostname = Get-SecretValue -SecretId $bodsConfigName -SecretKey "cms_primary_node_hostname" -ErrorAction SilentlyContinue

    # Create response file for IPS silent install
    $ipsResponseFilePrimary = @"
### Choose to integrate Introscope Enterprise Manager: integrate or nointegrate
chooseintroscopeintegration=nointegrate
### Choose to integrate Solution Manager Diagnostics (SMD) Agent: integrate or nointegrate
choosesmdintegration=nointegrate
### CMS cluster key
clusterkey=$bods_cluster_key
### CMS administrator password
# cmspassword=**** bods_admin_password value in silent install params, replaced with $bods_cluster_key value
### CMS connection port
cmsport=6400
### Existing auditing DB password
# existingauditingdbpassword=**** bods_ips_audit_owner value in silent install params
### Existing auditing DB server
existingauditingdbserver=DMDDSD # FIXME: needs pulling from a config file
### Existing auditing DB user name
existingauditingdbuser=dfi_mod_ipsaud # FIXME: needs pulling from a config file
### Existing CMS DB password
# existingcmsdbpassword=**** bods_ips_system_owner value in silent install params
### Existing CMS DB reset flag: 0 or 1 where 1 means don't reset <<<<<<-- check this
existingcmsdbreset=1
### Existing CMS DB server
existingcmsdbserver=DMDDSD # FIXME: needs pulling from a config file
### Existing CMS DB user name
existingcmsdbuser=dfi_mod_ipscms # FIXME: needs pulling from a config file
### Installation Directory
installdir=D:\BusinessObjects\
### Choose install type: default, custom, webtier
installtype=default
### Install new or use existing LCM: new or existing
neworexistinglcm=existing
### Product Keycode
productkey=$ips_product_key
### Language Packs Selected to Install
selectedlanguagepacks=en
### Setup UI Language
setupuilanguage=en
### SIA node name
sianame=NDLMODDFI101
### SIA connector port
siaport=6410
### Tomcat connection port
tomcatconnectionport=8080
### Tomcat redirect port
tomcatredirectport=8443
### Tomcat shutdown port
tomcatshutdownport=8005
### Auditing Database Type
usingauditdbtype=oracle
### CMS Database Type
usingcmsdbtype=oracle
### Web Application Server type: tomcat, manual or wacs
webappservertype=tomcat
### Features to install
features=JavaWebApps1,CMC.Monitoring,LCM,IntegratedTomcat,CMC.AccessLevels,CMC.Applications,CMC.Audit,CMC.Authentication,CMC.Calendars,CMC.Categories,CMC.CryptographicKey,CMC.Events,CMC.Folders,CMC.Inboxes,CMC.Licenses,CMC.PersonalCategories,CMC.PersonalFolders,CMC.Servers,CMC.Sessions,CMC.Settings,CMC.TemporaryStorage,CMC.UsersAndGroups,CMC.QueryResults,CMC.InstanceManager,CMS,FRS,PlatformServers.AdaptiveProcessingServer,PlatformServers.AdaptiveJobServer,ClientAuditingProxyProcessingService,LCMProcessingServices,MonitoringProcessingService,SecurityTokenService,DestinationSchedulingService,ProgramSchedulingService,AdminTools,DataAccess.SAP,DataAccess.Peoplesoft,DataAccess.JDEdwards,DataAccess.Siebel,DataAccess.OracleEBS,DataAccess
"@

    # FIXME: this isn't going to work anymore
    # $remoteSiaName = $cms_primary_node_hostname.Replace("-", "").ToUpper()
    $remoteSiaName = "NDLMODDFI101" # FIXME: this is hardcoded for expediency, needs refactoring later

    # FIXME: this is NOT WORKING - needs fixing for 4.3 version of expanded node
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
existingcmsdbserver=DMDDSD # FIXME: needs pulling from a config file
### Existing CMS DB user name
existingcmsdbuser=dfi_mod_ipscms
### Installation Directory
installdir=D:\SAP BusinessObjects\
### Choose install type: default, custom, webtier
installtype=default
### Choose install mode: new, expand
neworexpandinstall=expand
### Product Keycode
productkey=$ips_product_key
### Remote CMS administrator name
remotecmsadminname=Administrator
### Remote CMS administrator password
# remotecmsadminpassword=**** bods_admin_password value in silent install params
### Remote CMS name
remotecmsname=$cms_primary_node_hostname.$($Config.domainName)
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



    $ipsInstallIni = "$WorkingDirectory\IPS\ips_install.ini"

    # if ($($Config.Name) -eq $($Config.cmsPrimaryNode)) {
    #     $ipsResponseFilePrimary | Out-File -FilePath "$ipsInstallIni" -Force -Encoding ascii
    # }
    # elseif ($($Config.Name) -eq $($Config.cmsSecondaryNode)) {
    #     $ipsResponseFileSecondary | Out-File -FilePath "$ipsInstallIni" -Force -Encoding ascii
    # }
    # else {
    #     Write-Output "Unknown node type, cannot create response file"
    #     exit 1
    # }

    if ($($Config.Name -replace 'delius-mis','ndmis') -eq $Config.cmsPrimaryNode) {
        $ipsResponseFilePrimary | Out-File -FilePath "$ipsInstallIni" -Force -Encoding ascii
    }
    elseif ($($Config.Name -replace 'delius-mis','ndmis') -eq $Config.cmsSecondaryNode) {
        $ipsResponseFileSecondary | Out-File -FilePath "$ipsInstallIni" -Force -Encoding ascii
    }
    else {
        Write-Output "Unknown node type, cannot create response file"
        exit 1
    }

    Clear-PendingFileRenameOperations

    $setupExe = "$WorkingDirectory\IPS\setup.exe"

    if (-NOT(Test-Path $setupExe)) {
        Write-Host "IPS setup.exe not found at $($setupExe)"
        exit 1
    }

    if (-NOT(Test-Path $ipsInstallIni)) {
        Write-Host "IPS response file not found at $ipsInstallIni"
        exit 1
    }

    $logFile = "$WorkingDirectory\IPS\install_ips_sp.log"
    New-Item -Type File -Path $logFile -Force | Out-Null

    # add Oracle client path to the powershell session
    $env:Path += ";E:\app\oracle\product\19.0.0\client_1\bin"

    $env:Path -split ";" | ForEach-Object {
        Write-Host $_
    }

    Write-Host "Starting IPS installer at $(Get-Date)"

    try {
        "Starting IPS installer at $(Get-Date)" | Out-File -FilePath $logFile -Append
        if ($($Config.Name) -eq $($Config.cmsPrimaryNode)) {
            $process = Start-Process -FilePath "$WorkingDirectory\IPS\setup.exe" -ArgumentList '/wait', '-r D:\Software\IPS\ips_install.ini', "cmspassword=$bods_cluster_key", "existingauditingdbpassword=$bods_ips_audit_owner", "existingcmsdbpassword=$bods_ips_system_owner" -Wait -NoNewWindow -Verbose -PassThru
        }
        elseif ($($Config.Name) -eq $($Config.cmsSecondaryNode)) {
            $process = Start-Process -FilePath "$WorkingDirectory\IPS\setup.exe" -ArgumentList '/wait', '-r D:\Software\IPS\ips_install.ini', "remotecmsadminpassword=$bods_cluster_key", "existingcmsdbpassword=$bods_ips_system_owner" -Wait -NoNewWindow -Verbose -PassThru
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

# Test secrets first
$Config = Get-Config
$Config

$bods_ips_system_owner = Get-SecretValue -SecretId "delius-mis-dev-oracle-dsd-db-application-passwords" -SecretKey "dfi_mod_ipscms" -ErrorAction SilentlyContinue
$bods_ips_audit_owner = Get-SecretValue -SecretId "delius-mis-dev-oracle-dsd-db-application-passwords" -SecretKey "dfi_mod_ipsaud" -ErrorAction SilentlyContinue
$bods_cluster_key = Get-SecretValue -SecretId 'NDMIS_DFI_SERVICEACCOUNTS_DEV' -SecretKey "IPS_Administrator_LCMS_Administrator" -ErrorAction SilentlyContinue
$ips_product_key = Get-SecretValue -SecretId 'NDMIS_DFI_SERVICEACCOUNTS_DEV' -SecretKey "ips_product_key" -ErrorAction SilentlyContinue

Write-Output "bods_ips_system_owner: $bods_ips_system_owner"
Write-Output "bods_ips_audit_owner: $bods_ips_audit_owner"
Write-Output "bods_cluster_key: $bods_cluster_key"
Write-Output "ips_product_key: $ips_product_key"

Install-IPS -Config (Get-Config)
# Exit with the last exit code from the installer
