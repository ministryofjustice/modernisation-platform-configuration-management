# Unified BODS Configuration System
# This module provides consistent configuration management across all BODS environments

# Import the template
. (Join-Path $PSScriptRoot 'unified_config_template.ps1')

function Get-UnifiedConfig {
    param(
        [Parameter(Mandatory)]
        [string]$EnvironmentName,
        
        [Parameter(Mandatory)]
        [string]$Application,
        
        [Parameter()]
        [hashtable]$AdditionalTags = @{}
    )

    # Load application-specific config
    $configPath = switch ($Application) {
        'oasys-national-reporting' { Join-Path $PSScriptRoot 'ONR\onr_unified_config.ps1' }
        'nomis-combined-reporting' { Join-Path $PSScriptRoot 'NCR\ncr_unified_config.ps1' }
        'delius-mis' { Join-Path $PSScriptRoot 'MISDis\misdis_unified_config.ps1' }
        default { throw "Unsupported application: $Application" }
    }

    if (-not (Test-Path $configPath)) {
        throw "Config file not found: $configPath"
    }

    . $configPath

    # Get base config
    $baseConfig = $UnifiedConfigTemplate.all
    
    # Determine which cluster this machine belongs to by finding the configuration
    # where this machine's name matches either the primary or secondary node
    $clusterConfig = $null
    $configKey = $null
    $detectedRole = 'unknown'
    $machineName = $AdditionalTags.Name
    
    # Normalize machine name for MISDis if needed
    $normalizedMachineName = if ($Application -eq 'delius-mis') {
        $machineName -replace 'delius-mis', 'ndmis'
    } else {
        $machineName
    }
    
    Write-Verbose "Looking for configuration for machine: $machineName (normalized: $normalizedMachineName)"
    
    # Search through all configurations to find which cluster this machine belongs to
    foreach ($configName in $ApplicationConfig.Keys) {
        if ($configName -eq 'all') { continue }
        
        $config = $ApplicationConfig[$configName]
        if ($config.ContainsKey('NodeConfig')) {
            $primaryNode = $config.NodeConfig.cmsPrimaryNode
            $secondaryNode = $config.NodeConfig.cmsSecondaryNode
            
            # Check if this machine matches the primary or secondary node
            $isMatch = $false
            if ($machineName -eq $primaryNode) {
                $isMatch = $true
                $detectedRole = 'primary'
            } elseif ($normalizedMachineName -eq $primaryNode) {
                $isMatch = $true
                $detectedRole = 'primary'
            } elseif ($machineName -eq $secondaryNode) {
                $isMatch = $true
                $detectedRole = 'secondary'
            } elseif ($normalizedMachineName -eq $secondaryNode) {
                $isMatch = $true
                $detectedRole = 'secondary'
            }
            
            if ($isMatch) {
                $clusterConfig = $config
                $configKey = $configName
                Write-Verbose "Found matching cluster configuration: $configKey (role: $detectedRole)"
                break
            }
        }
    }
    
    # If no specific cluster found, try to use base environment config
    if ($null -eq $clusterConfig) {
        if ($ApplicationConfig.ContainsKey($EnvironmentName)) {
            $clusterConfig = $ApplicationConfig[$EnvironmentName]
            $configKey = $EnvironmentName
            Write-Verbose "Using base environment config: $configKey"
            
            # Try to determine role from base config
            if ($clusterConfig.ContainsKey('NodeConfig')) {
                $primaryNode = $clusterConfig.NodeConfig.cmsPrimaryNode
                $secondaryNode = $clusterConfig.NodeConfig.cmsSecondaryNode
                
                if ($machineName -eq $primaryNode -or $normalizedMachineName -eq $primaryNode) {
                    $detectedRole = 'primary'
                } elseif ($machineName -eq $secondaryNode -or $normalizedMachineName -eq $secondaryNode) {
                    $detectedRole = 'secondary'
                }
            }
        } else {
            Write-Warning "No configuration found for machine '$machineName' in environment '$EnvironmentName'"
            $clusterConfig = @{}
        }
    }
    
    # Merge configurations
    $mergedConfig = Merge-ConfigWithTemplate -Template @{'all' = $baseConfig } -EnvironmentConfig @{'all' = $clusterConfig }
    $finalConfig = $mergedConfig.all

    # Add application-specific overrides
    if ($ApplicationConfig.ContainsKey('all')) {
        $finalConfig = Merge-ConfigWithTemplate -Template @{'all' = $finalConfig } -EnvironmentConfig @{'all' = $ApplicationConfig.all }
        $finalConfig = $finalConfig.all
    }

    # Add additional tags
    foreach ($key in $AdditionalTags.Keys) {
        $finalConfig[$key] = $AdditionalTags[$key]
    }
    
    # Add computed fields
    $finalConfig['ConfigKey'] = $configKey
    $finalConfig['DetectedRole'] = $detectedRole
    $finalConfig['NormalizedMachineName'] = $normalizedMachineName

    return $finalConfig
}

function Get-SecretValueUnified {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config,
        
        [Parameter(Mandatory)]
        [string]$SecretType,
        
        [Parameter(Mandatory)]
        [string]$SecretKey,
        
        [Parameter()]
        [switch]$TestMode
    )

    if ($TestMode) {
        return "TEST_VALUE_$($SecretType)_$($SecretKey)"
    }

    $secretId = switch ($Config.SecretConfig.secretPattern) {
        'standard' {
            switch ($SecretType) {
                'bods_passwords' { $Config.SecretConfig.secretMappings.bodsSecretName -replace '\{dbenv\}', $Config.dbenv }
                'bods_config' { $Config.SecretConfig.secretMappings.bodsConfigName -replace '\{dbenv\}', $Config.dbenv }
                'sys_db' { $Config.SecretConfig.secretMappings.sysDbSecretName -replace '\{sysDbName\}', $Config.DatabaseConfig.sysDbName }
                'aud_db' { $Config.SecretConfig.secretMappings.audDbSecretName -replace '\{audDbName\}', $Config.DatabaseConfig.audDbName }
                default { throw "Unknown secret type: $SecretType" }
            }
        }
        'misdis' {
            switch ($SecretType) {
                'service_accounts' { 'NDMIS_DFI_SERVICEACCOUNTS_DEV' }
                'sys_db' { 'delius-mis-dev-oracle-dsd-db-application-passwords' }
                'aud_db' { 'delius-mis-dev-oracle-dsd-db-application-passwords' }
                default { throw "Unknown secret type for MISDis: $SecretType" }
            }
        }
        default { throw "Unknown secret pattern: $($Config.SecretConfig.secretPattern)" }
    }

    try {
        $secretJson = aws secretsmanager get-secret-value --secret-id $secretId --query SecretString --output text

        if ($null -eq $secretJson -or $secretJson -eq '') {
            Write-Warning "The SecretId '$secretId' does not exist or returned no value."
            return $null
        }

        $secretObject = $secretJson | ConvertFrom-Json

        if (-not $secretObject.PSObject.Properties.Name -contains $SecretKey) {
            Write-Warning "The SecretKey '$SecretKey' does not exist in the secret."
            return $null
        }

        return $secretObject.$SecretKey
    }
    catch {
        Write-Warning "An error occurred while retrieving the secret: $_"
        return $null
    }
}

function New-ResponseFileFromTemplate {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        
        [Parameter(Mandatory)]
        [string]$TemplateName,
        
        [Parameter(Mandatory)]
        [string]$OutputPath,
        
        [Parameter()]
        [switch]$TestMode
    )

    # Determine BODS version and adjust template name accordingly
    $bodsVersion = '42' # Default to 4.2
    if ($Config.application -eq 'delius-mis') {
        $bodsVersion = '43' # MISDis uses 4.3
    }
    
    # Map logical template names to actual template files based on version
    $actualTemplateName = switch ($TemplateName) {
        'IPS_Primary_Template.ini' { 
            if ($bodsVersion -eq '43') { 'IPS_Primary_Template_43.ini' } else { 'IPS_Primary_Template.ini' }
        }
        'IPS_Secondary_Template.ini' { 
            if ($bodsVersion -eq '43') { 'IPS_Secondary_Template_43.ini' } else { 'IPS_Secondary_Template.ini' }
        }
        'DataServices_Primary_Template.ini' { 
            if ($bodsVersion -eq '43') { 'DataServices_Primary_Template_43.ini' } else { 'DataServices_Primary_Template.ini' }
        }
        'DataServices_Secondary_Template.ini' { 
            if ($bodsVersion -eq '43') { 'DataServices_Secondary_Template_43.ini' } else { 'DataServices_Secondary_Template.ini' }
        }
        default { $TemplateName }
    }

    $templatePath = Join-Path $PSScriptRoot "ResponseTemplates\$actualTemplateName"
    
    if (-not (Test-Path $templatePath)) {
        throw "Template file not found: $templatePath"
    }

    $templateContent = Get-Content $templatePath -Raw

    # Define variable mappings based on template type and version
    $variableMappings = switch -Wildcard ($actualTemplateName) {
        '*IPS_Primary_Template*.ini' {
            @{
                'CLUSTER_KEY'            = Get-SecretValueUnified -Config $Config -SecretType 'bods_passwords' -SecretKey 'bods_admin_password' -TestMode:$TestMode
                'AUD_DB_NAME'            = $Config.DatabaseConfig.audDbName
                'AUD_DB_USER'            = $Config.DatabaseConfig.audDbUser
                'SYS_DB_NAME'            = $Config.DatabaseConfig.sysDbName
                'SYS_DB_USER'            = $Config.DatabaseConfig.sysDbUser
                'INSTALL_DIR'            = if ($bodsVersion -eq '43') { 
                    $Config.BIP_INSTALL_DIR -replace 'SAP BusinessObjects Enterprise XI 4.0', ''
                }
                else { 
                    $Config.BIP_INSTALL_DIR -replace 'SAP BusinessObjects Enterprise XI 4.0', ''
                }
                'INSTALL_TYPE'           = if ($Config.ContainsKey('IPSInstallType')) { $Config.IPSInstallType } else { 
                    if ($bodsVersion -eq '43') { 'default' } else { 'custom' }
                }
                'LCM_NAME'               = if ($Config.ContainsKey('LCMName')) { $Config.LCMName } else { 'LCM_repository' }
                'LCM_PORT'               = if ($Config.ContainsKey('LCMPort')) { $Config.LCMPort } else { '3690' }
                'LCM_USERNAME'           = if ($Config.ContainsKey('LCMUsername')) { $Config.LCMUsername } else { 'LCM' }
                'PRODUCT_KEY'            = Get-SecretValueUnified -Config $Config -SecretType 'bods_config' -SecretKey 'ips_product_key' -TestMode:$TestMode
                'SIA_NODE_NAME'          = if ($Config.ContainsKey('SiaNodeName')) { 
                    $Config.SiaNodeName 
                }
                else { 
                    $Config.Name.Replace('-', '').ToUpper()
                }
                'TOMCAT_CONNECTION_PORT' = if ($Config.ContainsKey('TomcatConnectionPort')) { 
                    $Config.TomcatConnectionPort 
                }
                else { 
                    if ($bodsVersion -eq '43') { '8080' } else { '28080' }
                }
                'WEBAPP_SERVER_TYPE'     = if ($Config.ContainsKey('WebAppServerType')) { $Config.WebAppServerType } else { 'tomcat' }
                'NEW_OR_EXISTING_LCM'    = if ($Config.ContainsKey('NewOrExistingLCM')) { $Config.NewOrExistingLCM } else { 'existing' }
                'FEATURES'               = if ($Config.ContainsKey('IPSFeatures')) { 
                    $Config.IPSFeatures 
                }
                else { 
                    if ($bodsVersion -eq '43') {
                        # MISDis 4.3 features (includes additional DataAccess components)
                        'JavaWebApps1,CMC.Monitoring,LCM,IntegratedTomcat,CMC.AccessLevels,CMC.Applications,CMC.Audit,CMC.Authentication,CMC.Calendars,CMC.Categories,CMC.CryptographicKey,CMC.Events,CMC.Folders,CMC.Inboxes,CMC.Licenses,CMC.PersonalCategories,CMC.PersonalFolders,CMC.Servers,CMC.Sessions,CMC.Settings,CMC.TemporaryStorage,CMC.UsersAndGroups,CMC.QueryResults,CMC.InstanceManager,CMS,FRS,PlatformServers.AdaptiveProcessingServer,PlatformServers.AdaptiveJobServer,ClientAuditingProxyProcessingService,LCMProcessingServices,MonitoringProcessingService,SecurityTokenService,DestinationSchedulingService,ProgramSchedulingService,AdminTools,DataAccess.SAP,DataAccess.Peoplesoft,DataAccess.JDEdwards,DataAccess.Siebel,DataAccess.OracleEBS,DataAccess'
                    }
                    else {
                        # ONR/NCR 4.2 features
                        'JavaWebApps1,CMC.Monitoring,LCM,IntegratedTomcat,CMC.AccessLevels,CMC.Applications,CMC.Audit,CMC.Authentication,CMC.Calendars,CMC.Categories,CMC.CryptographicKey,CMC.Events,CMC.Folders,CMC.Inboxes,CMC.Licenses,CMC.PersonalCategories,CMC.PersonalFolders,CMC.Servers,CMC.Sessions,CMC.Settings,CMC.TemporaryStorage,CMC.UsersAndGroups,CMC.QueryResults,CMC.InstanceManager,CMS,FRS,PlatformServers.AdaptiveProcessingServer,PlatformServers.AdaptiveJobServer,ClientAuditingProxyProcessingService,LCMProcessingServices,MonitoringProcessingService,SecurityTokenService,DestinationSchedulingService,ProgramSchedulingService,Subversion,UpgradeManager,AdminTools'
                    }
                }
            }
        }
        '*IPS_Secondary_Template*.ini' {
            @{
                'CLUSTER_KEY'            = Get-SecretValueUnified -Config $Config -SecretType 'bods_passwords' -SecretKey 'bods_admin_password' -TestMode:$TestMode
                'SYS_DB_NAME'            = $Config.DatabaseConfig.sysDbName
                'SYS_DB_USER'            = $Config.DatabaseConfig.sysDbUser
                'INSTALL_DIR'            = if ($bodsVersion -eq '43') { 
                    $Config.BIP_INSTALL_DIR -replace 'SAP BusinessObjects Enterprise XI 4.0', ''
                }
                else { 
                    $Config.BIP_INSTALL_DIR -replace 'SAP BusinessObjects Enterprise XI 4.0', ''
                }
                'INSTALL_TYPE'           = if ($Config.ContainsKey('IPSInstallType')) { $Config.IPSInstallType } else { 
                    if ($bodsVersion -eq '43') { 'default' } else { 'custom' }
                }
                'PRODUCT_KEY'            = Get-SecretValueUnified -Config $Config -SecretType 'bods_config' -SecretKey 'ips_product_key' -TestMode:$TestMode
                'REMOTE_CMS_NAME'        = "$($Config.NodeConfig.cmsPrimaryNode).$($Config.domainName)"
                'SIA_NODE_NAME'          = if ($Config.ContainsKey('SiaNodeName')) { 
                    $Config.SiaNodeName 
                }
                else { 
                    $Config.Name.Replace('-', '').ToUpper()
                }
                'TOMCAT_CONNECTION_PORT' = if ($Config.ContainsKey('TomcatConnectionPort')) { 
                    $Config.TomcatConnectionPort 
                }
                else { 
                    if ($bodsVersion -eq '43') { '8080' } else { '28080' }
                }
                'FEATURES'               = if ($Config.ContainsKey('IPSFeatures')) { 
                    $Config.IPSFeatures 
                }
                else { 
                    if ($bodsVersion -eq '43') {
                        'JavaWebApps1,CMC.Monitoring,LCM,IntegratedTomcat,CMC.AccessLevels,CMC.Applications,CMC.Audit,CMC.Authentication,CMC.Calendars,CMC.Categories,CMC.CryptographicKey,CMC.Events,CMC.Folders,CMC.Inboxes,CMC.Licenses,CMC.PersonalCategories,CMC.PersonalFolders,CMC.Servers,CMC.Sessions,CMC.Settings,CMC.TemporaryStorage,CMC.UsersAndGroups,CMC.QueryResults,CMC.InstanceManager,CMS,FRS,PlatformServers.AdaptiveProcessingServer,PlatformServers.AdaptiveJobServer,ClientAuditingProxyProcessingService,LCMProcessingServices,MonitoringProcessingService,SecurityTokenService,DestinationSchedulingService,ProgramSchedulingService,Subversion,UpgradeManager,AdminTools'
                    }
                    else {
                        'JavaWebApps1,CMC.Monitoring,LCM,IntegratedTomcat,CMC.AccessLevels,CMC.Applications,CMC.Audit,CMC.Authentication,CMC.Calendars,CMC.Categories,CMC.CryptographicKey,CMC.Events,CMC.Folders,CMC.Inboxes,CMC.Licenses,CMC.PersonalCategories,CMC.PersonalFolders,CMC.Servers,CMC.Sessions,CMC.Settings,CMC.TemporaryStorage,CMC.UsersAndGroups,CMC.QueryResults,CMC.InstanceManager,CMS,FRS,PlatformServers.AdaptiveProcessingServer,PlatformServers.AdaptiveJobServer,ClientAuditingProxyProcessingService,LCMProcessingServices,MonitoringProcessingService,SecurityTokenService,DestinationSchedulingService,ProgramSchedulingService,Subversion,UpgradeManager,AdminTools'
                    }
                }
            }
        }
        '*DataServices_*_Template*.ini' {
            @{
                'CMS_SYSTEM'          = if ($actualTemplateName -match 'Secondary') {
                    "$($Config.NodeConfig.cmsPrimaryNode).$($Config.domainName):6400"
                }
                else {
                    "$($env:COMPUTERNAME):6400"
                }
                'REMOTE_CMS_SYSTEM'   = "$($Config.NodeConfig.cmsPrimaryNode).$($Config.domainName):6400"
                'DS_COMMON_DIR'       = $Config.dscommondir
                'SERVICE_USER_DOMAIN' = $Config.ServiceConfig.domain
                'SERVICE_USER'        = $Config.ServiceConfig.serviceUser
                'INSTALL_DIR'         = $Config.LINK_DIR -replace 'Data Services', ''
                'MASTER_CMS_NAME'     = if ($actualTemplateName -match 'Secondary') {
                    "$($Config.NodeConfig.cmsPrimaryNode).$($Config.domainName)"
                }
                else {
                    "$($env:COMPUTERNAME)"
                }
                'PRODUCT_KEY'         = Get-SecretValueUnified -Config $Config -SecretType 'bods_config' -SecretKey 'data_services_product_key' -TestMode:$TestMode
                'FEATURES'            = if ($Config.ContainsKey('DataServicesFeatures')) { 
                    $Config.DataServicesFeatures 
                }
                else { 
                    'DataServicesJobServer,DataServicesAccessServer,DataServicesServer,DataServicesDesigner,DataServicesClient,DataServicesManagementConsole,DataServicesEIMServices,DataServicesMessageClient,DataServicesDataDirect,DataServicesDocumentation'
                }
            }
        }
        default { throw "Unknown template: $actualTemplateName" }
    }

    # Replace variables in template
    $processedContent = $templateContent
    foreach ($variable in $variableMappings.Keys) {
        $value = $variableMappings[$variable]
        $processedContent = $processedContent -replace "\{$variable\}", $value
    }

    # Write the processed content to output file
    $processedContent | Out-File -FilePath $OutputPath -Force -Encoding ascii

    # Return command line arguments for sensitive parameters
    $commandLineArgs = switch -Wildcard ($actualTemplateName) {
        '*IPS_Primary_Template*.ini' {
            $commandArgs = @(
                "cmspassword=$(Get-SecretValueUnified -Config $Config -SecretType 'bods_passwords' -SecretKey 'bods_admin_password' -TestMode:$TestMode)",
                "existingauditingdbpassword=$(Get-SecretValueUnified -Config $Config -SecretType 'aud_db' -SecretKey $Config.DatabaseConfig.audDbUser -TestMode:$TestMode)",
                "existingcmsdbpassword=$(Get-SecretValueUnified -Config $Config -SecretType 'sys_db' -SecretKey $Config.DatabaseConfig.sysDbUser -TestMode:$TestMode)"
            )
            if ($Config.ContainsKey('LCMUsername')) {
                $commandArgs += "lcmpassword=$(Get-SecretValueUnified -Config $Config -SecretType 'bods_passwords' -SecretKey 'bods_subversion_password' -TestMode:$TestMode)"
            }
            $commandArgs
        }
        '*IPS_Secondary_Template*.ini' {
            @(
                "remotecmsadminpassword=$(Get-SecretValueUnified -Config $Config -SecretType 'bods_passwords' -SecretKey 'bods_admin_password' -TestMode:$TestMode)",
                "existingcmsdbpassword=$(Get-SecretValueUnified -Config $Config -SecretType 'sys_db' -SecretKey $Config.DatabaseConfig.sysDbUser -TestMode:$TestMode)"
            )
        }
        '*DataServices_*_Template*.ini' {
            @(
                "cmspassword=$(Get-SecretValueUnified -Config $Config -SecretType 'bods_passwords' -SecretKey 'bods_admin_password' -TestMode:$TestMode)",
                "dscmspassword=$(Get-SecretValueUnified -Config $Config -SecretType 'bods_passwords' -SecretKey 'bods_admin_password' -TestMode:$TestMode)",
                "dslogininfothispassword=$(Get-SecretValueUnified -Config $Config -SecretType 'service_accounts' -SecretKey $Config.ServiceConfig.serviceUser -TestMode:$TestMode)"
            )
        }
        default { @() }
    }

    return @{
        'ResponseFile'    = $OutputPath
        'CommandLineArgs' = $commandLineArgs
        'TemplateUsed'    = $actualTemplateName
        'BODSVersion'     = $bodsVersion
    }
}
