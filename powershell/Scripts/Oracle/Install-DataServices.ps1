function Install-DataServices {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    if (Get-Package | Where-Object { $_.Name -Like "SAP Data Services*" }) {
        Write-Output "Data Services is already installed"
        return
    }

    # easier to fix here rather than do command substitution inside the install params
    $WorkingDirectory = $Config.WorkingDirectory

    Get-Installer -Key $Config.DataServicesS3File -Destination (".\" + $Config.DataServicesS3File)

    if ($($Config.application) -eq "nomis-combined-reporting") {
        Expand-Archive -Path (".\" + $Config.DataServicesS3File) -Destination ".\DataServices"
        $dataServicesInstallerFilePath = "$WorkingDirectory\$($Config.DataServicesS3File)\DataServices\setup.exe"
    }
    else {
        $dataServicesInstallerFilePath = "$WorkingDirectory\$($Config.DataServicesS3File)"
    }

    [Environment]::SetEnvironmentVariable("LINK_DIR", $Config.LINK_DIR, [System.EnvironmentVariableTarget]::Machine)

    if (-NOT(Test-Path "F:\BODS_COMMON_DIR")) {
        Write-Output "Creating F:\BODS_COMMON_DIR"
        New-Item -ItemType Directory -Path "F:\BODS_COMMON_DIR"
    }
    [Environment]::SetEnvironmentVariable("DS_COMMON_DIR", "F:\BODS_COMMON_DIR", [System.EnvironmentVariableTarget]::Machine)

    # set Secret Names based on environment
    $bodsSecretName = "/sap/bods/$($Config.dbenv)/passwords"
    $bodsConfigName = "/sap/bods/$($Config.dbenv)/config"

    # passwords from /sap/bods/$dbenv/passwords
    $service_user_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "svc_nart" -ErrorAction SilentlyContinue
    $bods_admin_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_admin_password" -ErrorAction SilentlyContinue

    # config values from /sap/bods/$dbenv/config
    $data_services_product_key = Get-SecretValue -SecretId $bodsConfigName -SecretKey "data_services_product_key" -ErrorAction SilentlyContinue
    $cms_primary_node_hostname = Get-SecretValue -SecretId $bodsConfigName -SecretKey "cms_primary_node_hostname" -ErrorAction SilentlyContinue

    $dataServicesResponsePrimary = @"
### #property.CMSAUTHENTICATION.description#
cmsauthentication=secEnterprise
### CMS administrator password
# cmspassword=**** bods_admin_password in silent install params
### #property.CMSUSERNAME.description#
cmsusername=Administrator
### #property.CMSEnabledSSL.description#
dscmsenablessl=0
### CMS administrator password
# dscmspassword=**** bods_admin_password value in silent install params
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
# dslogininfothispassword=**** service_user_password value in silent install params
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
dscmssystem=$cms_primary_node_hostname.$($Config.domainName)
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
mastercmsname=$cms_primary_node_hostname.$($Config.domainName)
### #property.MasterCmsPort.description#
mastercmsport=6400
### Keycode for the product.
productkey=$data_services_product_key
### *** property.SelectedLanguagePacks.description ***
selectedlanguagepacks=en
### Available features
features=DataServicesJobServer,DataServicesAccessServer,DataServicesServer,DataServicesDesigner,DataServicesClient,DataServicesManagementConsole,DataServicesEIMServices,DataServicesMessageClient,DataServicesDataDirect,DataServicesDocumentation
"@

    $dsInstallIni = "$WorkingDirectory\ds_install.ini"

    if ($($Config.Name) -eq $Config.cmsPrimaryNode) {
        $dataServicesResponsePrimary | Out-File -FilePath $dsInstallIni -Force -Encoding ascii
    }
    elseif ($($Config.Name) -eq $Config.cmsSecondaryNode) {
        $dataServicesResponseSecondary | Out-File -FilePath $dsInstallIni -Force -Encoding ascii
    }
    else {
        Write-Output "Unknown node type, cannot create response file"
        exit 1
    }

    $dataServicesInstallParams = @{
        FilePath     = $dataServicesInstallerFilePath
        ArgumentList = "-q", "-r", "$dsInstallIni", "cmspassword=$bods_admin_password", "dscmspassword=$bods_admin_password", "dslogininfothispassword=$service_user_password"
        Wait         = $true
        NoNewWindow  = $true
    }

    # Install Data Services
    Start-Process @dataServicesInstallParams

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
