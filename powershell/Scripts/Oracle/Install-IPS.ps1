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
    
    # FIXME: This won't work in a sustainable way
    $dbenvTag = ($Tags.Tags | Where-Object { $_.Key -eq "oasys-national-reporting-environment" }).Value

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
        Write-Output "Using Server-Type tag to determine config path"
        $configPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Configs\$serverType\$($serverType)_config.ps1"
    }

    # dot source the config file containing $GlobalConfig
    . $configPath

    if (-not $GlobalConfig.Contains($EnvironmentNameTag)) {
        Write-Error "Unexpected environment-name tag value $EnvironmentNameTag"
    }

    $additionalConfig = @{
        application = $ApplicationTag
        dbenv       = $dbenvTag
        Name        = $nameTag
        domainName  = $domainName
    }

    Return $GlobalConfig.all + $GlobalConfig[$EnvironmentNameTag] + $additionalConfig
}

function Install-IPS {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    # easier to fix here rather than do command substitution inside the install params
    $WorkingDirectory = $Config.WorkingDirectory

    if (Test-Path "$WorkingDirectory\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0") {
        Write-Output "IPS is already installed"
        return
    }

    Get-Installer -Key $Config.IPSS3File -Destination (".\" + $Config.IPSS3File)

    Expand-Archive ( ".\" + $Config.IPSS3File) -Destination ".\IPS"

    # set Secret Names based on environment
    $siaNodeName = $Config.SiaNodeName
    $bodsSecretName = "/sap/bods/$($Config.dbenv)/passwords"
    $bodsConfigName = "/sap/bods/$($Config.dbenv)/config"
    $sysDbSecretName = "/oracle/database/$($Config.sysDbName)/passwords" # FIXME: check this works/is available format in MISDis environment
    $audDbSecretName = "/oracle/database/$($Config.audDbName)/passwords" # FIXME: check this works/is available format in MISDis environment

    # Get secret values from relevant db's secrets
    $bods_ips_system_owner = Get-SecretValue -SecretId $sysDbSecretName -SecretKey "bods_ips_system_owner" -ErrorAction SilentlyContinue
    $bods_ips_audit_owner = Get-SecretValue -SecretId $audDbSecretName -SecretKey "bods_ips_audit_owner" -ErrorAction SilentlyContinue

    # /sap/bods/$dbenv/passwords values
    $bods_admin_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_admin_password" -ErrorAction SilentlyContinue
    $bods_subversion_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_subversion_password" -ErrorAction SilentlyContinue

    # /sap/bods/$dbenv/config values
    $bods_cluster_key = Get-SecretValue -SecretId $bodsConfigName -SecretKey "bods_cluster_key" -ErrorAction SilentlyContinue
    $ips_product_key = Get-SecretValue -SecretId $bodsConfigName -SecretKey "ips_product_key" -ErrorAction SilentlyContinue
    $cms_primary_node_hostname = Get-SecretValue -SecretId $bodsConfigName -SecretKey "cms_primary_node_hostname" -ErrorAction SilentlyContinue

    # Create response file for IPS silent install
    $ipsResponseFilePrimary = @"
### Choose to integrate Introscope Enterprise Manager: integrate or nointegrate
chooseintroscopeintegration=nointegrate
### Choose to integrate Solution Manager Diagnostics (SMD) Agent: integrate or nointegrate
choosesmdintegration=nointegrate
### CMS cluster key
clusterkey=$bods_cluster_key
### CMS administrator password
# cmspassword=**** bods_admin_password value in silent install params
### CMS connection port
cmsport=6400
### Existing auditing DB password
# existingauditingdbpassword=**** bods_ips_audit_owner value in silent install params
### Existing auditing DB server
existingauditingdbserver=$($Config.audDbName)
### Existing auditing DB user name
existingauditingdbuser=bods_ips_audit_owner
### Existing CMS DB password
# existingcmsdbpassword=**** bods_ips_system_owner value in silent install params
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
# lcmpassword=**** bods_subversion_password value in silent install params
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

    $remoteSiaName = $cms_primary_node_hostname.Replace("-", "").ToUpper()

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


    $ipsInstallIni = "$WorkingDirectory\IPS\DATA_UNITS\IPS_win\ips_install.ini"

    if ($($Config.Name) -eq $($Config.cmsPrimaryNode)) {
        $ipsResponseFilePrimary | Out-File -FilePath "$ipsInstallIni" -Force -Encoding ascii
    }
    elseif ($($Config.Name) -eq $($Config.cmsSecondaryNode)) {
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
        if ($($Config.Name) -eq $($Config.cmsPrimaryNode)) {
            $process = Start-Process -FilePath "$WorkingDirectory\IPS\DATA_UNITS\IPS_win\setup.exe" -ArgumentList '/wait', "-r `"$ipsInstallIni`"", "cmspassword=$bods_admin_password", "existingauditingdbpassword=$bods_ips_audit_owner", "existingcmsdbpassword=$bods_ips_system_owner", "lcmpassword=$bods_subversion_password" -Wait -NoNewWindow -Verbose -PassThru
        }
        elseif ($($Config.Name) -eq $($Config.cmsSecondaryNode)) {
            $process = Start-Process -FilePath "$WorkingDirectory\IPS\DATA_UNITS\IPS_win\setup.exe" -ArgumentList '/wait', "-r `"$ipsInstallIni`"", "remotecmsadminpassword=$bods_admin_password", "existingcmsdbpassword=$bods_ips_system_owner", "lcmpassword=$bods_subversion_password" -Wait -NoNewWindow -Verbose -PassThru
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

Install-IPS -Config (Get-Config)
# Exit with the last exit code from the installer
