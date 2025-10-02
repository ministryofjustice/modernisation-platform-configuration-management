# MISDis Unified Configuration
# This config uses the unified template with MISDis-specific overrides

# suppress PSScript Analyzer warning - variable not in use.
[Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssignments', 'ApplicationConfig')]
param()  

$ApplicationConfig = @{ 
    'all'                    = @{
        # Override base template for MISDis-specific paths
        'WindowsClientS3Folder' = 'hmpps/mis'
        'IPSS3File'             = 'IPS4304P_900-70002778.EXE'
        'DataServicesS3File'    = 'DS4303P_4-80007397.EXE'
        
        # MISDis uses different drive structure
        'ORACLE_BASE'           = 'C:\app\oracle'
        'ORACLE_19C_HOME'       = 'C:\app\oracle\product\19.0.0\client_1'
        'LINK_DIR'              = 'D:\BusinessObjects\Data Services'
        'BIP_INSTALL_DIR'       = 'D:\BusinessObjects\SAP BusinessObjects Enterprise XI 4.0'
        'WorkingDirectory'      = 'D:\Software'
        'AppDirectory'          = 'D:\App'
        'dscommondir'           = 'D:\DSCommon\'
        
        # MISDis-specific secret configuration
        'SecretConfig'          = @{
            'secretPattern'  = 'misdis'
            'secretMappings' = @{
                'serviceAccounts' = 'NDMIS_DFI_SERVICEACCOUNTS_DEV'
                'sysDbSecrets'    = 'delius-mis-dev-oracle-dsd-db-application-passwords'
                'audDbSecrets'    = 'delius-mis-dev-oracle-dsd-db-application-passwords'
            }
        }
        
        # MISDis-specific installer settings
        'IPSInstallType'        = 'default'
        'TomcatConnectionPort'  = '8080'
        'WebAppServerType'      = 'tomcat'
        'NewOrExistingLCM'      = 'existing'
        
        # MISDis-specific features (different from ONR/NCR)
        'IPSFeatures'           = 'JavaWebApps1,CMC.Monitoring,LCM,IntegratedTomcat,CMC.AccessLevels,CMC.Applications,CMC.Audit,CMC.Authentication,CMC.Calendars,CMC.Categories,CMC.CryptographicKey,CMC.Events,CMC.Folders,CMC.Inboxes,CMC.Licenses,CMC.PersonalCategories,CMC.PersonalFolders,CMC.Servers,CMC.Sessions,CMC.Settings,CMC.TemporaryStorage,CMC.UsersAndGroups,CMC.QueryResults,CMC.InstanceManager,CMS,FRS,PlatformServers.AdaptiveProcessingServer,PlatformServers.AdaptiveJobServer,ClientAuditingProxyProcessingService,LCMProcessingServices,MonitoringProcessingService,SecurityTokenService,DestinationSchedulingService,ProgramSchedulingService,AdminTools,DataAccess.SAP,DataAccess.Peoplesoft,DataAccess.JDEdwards,DataAccess.Siebel,DataAccess.OracleEBS,DataAccess'
    }

    # Cluster-specific configurations (keyed by primary node name)
    'ndmis-dev-dfi-1'        = @{
        'EnvironmentName' = 'delius-mis-development'
        'ClusterName'     = 'dfi'
        
        'DatabaseConfig'  = @{
            'sysDbName' = 'DMDDSD'
            'audDbName' = 'DMDDSD'
            'sysDbUser' = 'dfi_mod_ipscms'
            'audDbUser' = 'dfi_mod_ipsaud'
        }
        
        'NodeConfig'      = @{
            'cmsPrimaryNode'   = 'ndmis-dev-dfi-1'
            'cmsSecondaryNode' = 'ndmis-dev-dfi-2'
        }
        
        'ServiceConfig'   = @{
            'serviceUser' = 'SVC_DFI_NDL'
            'domain'      = 'delius-mis-dev'
        }
        
        # Explicit secret configuration for DFI cluster
        'SecretConfig'    = @{
            'secretIds'  = @{
                'serviceAccounts' = 'NDMIS_DFI_SERVICEACCOUNTS_DEV'
                'bodsPasswords'   = 'NDMIS_DFI_SERVICEACCOUNTS_DEV'
                'bodsConfig'      = 'NDMIS_DFI_SERVICEACCOUNTS_DEV'
                'sysDbSecrets'    = 'delius-mis-dev-oracle-dsd-db-application-passwords'
                'audDbSecrets'    = 'delius-mis-dev-oracle-dsd-db-application-passwords'
            }
            'secretKeys' = @{
                'bodsAdminPassword'        = 'DFI_IPS_Administrator_LCMS_Administrator'
                'ipsProductKey'            = 'ips_product_key'
                'dataServicesProductKey'   = 'data_services_product_key'
                'serviceUserPassword'      = 'SVC_DFI_NDL'
                'sysDbUserPassword'        = 'dfi_mod_ipscms'
                'audDbUserPassword'        = 'dfi_mod_ipsaud'
                'sqlAnywhereAdminPassword' = 'sql_anywhere_admin_password'  # Required for 4.3 installer validation
            }
        }
        
        'SiaNodeName'     = 'NDLMODDFI101'
    }
    
    'ndmis-dev-dis-1'        = @{
        'EnvironmentName' = 'delius-mis-development'
        'ClusterName'     = 'dis'
        
        'DatabaseConfig'  = @{
            'sysDbName' = 'DMDDXB'  # Different database for DIS
            'audDbName' = 'DMDDXB'
            'sysDbUser' = 'ipscms'  # Different user for DIS
            'audDbUser' = 'ipsaud'
        }
        
        'NodeConfig'      = @{
            'cmsPrimaryNode'   = 'ndmis-dev-dis-1'
            'cmsSecondaryNode' = 'ndmis-dev-dis-2'
        }
        
        'ServiceConfig'   = @{
            'serviceUser' = 'SVC_DIS_NDL'
            'domain'      = 'delius-mis-dev'
        }
        
        # Explicit secret configuration for DIS cluster
        'SecretConfig'    = @{
            'secretIds'  = @{
                'serviceAccounts' = 'NDMIS_DFI_SERVICEACCOUNTS_DEV'
                'bodsPasswords'   = 'NDMIS_DFI_SERVICEACCOUNTS_DEV'
                'bodsConfig'      = 'NDMIS_DFI_SERVICEACCOUNTS_DEV'
                'sysDbSecrets'    = 'delius-mis-dev-oracle-dsd-db-application-passwords'
                'audDbSecrets'    = 'delius-mis-dev-oracle-dsd-db-application-passwords'
            }
            'secretKeys' = @{
                'bodsAdminPassword'        = 'DIS_IPS_Administrator_LCMS_Administrator'
                'ipsProductKey'            = 'ips_product_key'
                'dataServicesProductKey'   = 'data_services_product_key'
                'serviceUserPassword'      = 'SVC_DIS_NDL'
                'sysDbUserPassword'        = 'ipscms'
                'audDbUserPassword'        = 'ipsaud'
                'sqlAnywhereAdminPassword' = 'sql_anywhere_admin_password'  # Required for 4.3 installer validation
            }
        }
        
        'SiaNodeName'     = 'NDLMODDIS101'  # Different SIA node name for DIS
    }

    # EXAMPLE CONFIG ONLY - NEEDS CHANGING
    'delius-mis-stage-dfi-1' = @{
        'EnvironmentName' = 'delius-mis-preproduction'
        'ClusterName'     = 'stage'
        
        'DatabaseConfig'  = @{
            'sysDbName' = 'DMPDSD'
            'audDbName' = 'DMPDSD'
            'sysDbUser' = 'dfi_mod_ipscms'
            'audDbUser' = 'dfi_mod_ipsaud'
        }
        
        'NodeConfig'      = @{
            'cmsPrimaryNode'   = 'ndmis-stage-dfi-1'
            'cmsSecondaryNode' = 'ndmis-stage-dfi-2'
        }
        
        'ServiceConfig'   = @{
            'serviceUser' = 'SVC_DIS_NDL'
            'domain'      = 'delius-mis-preprod'
        }
        
        # Explicit secret configuration for Stage cluster
        'SecretConfig'    = @{
            'secretIds'  = @{
                'serviceAccounts' = 'NDMIS_DFI_SERVICEACCOUNTS_STAGE'
                'bodsPasswords'   = 'delius-mis-preprod-oracle-dsd-db-application-passwords'
                'bodsConfig'      = 'NDMIS_DFI_SERVICEACCOUNTS_STAGE'
                'sysDbSecrets'    = 'delius-mis-preprod-oracle-dsd-db-application-passwords'
                'audDbSecrets'    = 'delius-mis-preprod-oracle-dsd-db-application-passwords'
            }
            'secretKeys' = @{
                'bodsAdminPassword'      = 'DFI_IPS_Administrator_LCMS_Administrator'
                'ipsProductKey'          = 'ips_product_key'
                'dataServicesProductKey' = 'data_services_product_key'
                'bodsSubversionPassword' = 'bods_subversion_password'
                'serviceUserPassword'    = 'SVC_DFI_NDL'
                'sysDbUserPassword'      = 'dfi_mod_ipscms'
                'audDbUserPassword'      = 'dfi_mod_ipsaud'
            }
        }
        
        'SiaNodeName'     = 'NDLMODSTG101'
    }
    
    # EXAMPLE CONFIG ONLY - NEEDS CHANGING
    'delius-mis-pp-dfi-1'    = @{
        'EnvironmentName' = 'delius-mis-preproduction'
        'ClusterName'     = 'pp'
        
        'DatabaseConfig'  = @{
            'sysDbName' = 'DMPPSD'  # Different database for PP cluster
            'audDbName' = 'DMPPSD'
            'sysDbUser' = 'dfi_mod_ipscms'
            'audDbUser' = 'dfi_mod_ipsaud'
        }
        
        'NodeConfig'      = @{
            'cmsPrimaryNode'   = 'ndmis-pp-dfi-1'
            'cmsSecondaryNode' = 'ndmis-pp-dfi-2'
        }
        
        'ServiceConfig'   = @{
            'serviceUser' = 'SVC_DIS_NDL'
            'domain'      = 'delius-mis-preprod'
        }
        
        # Explicit secret configuration for PP cluster
        'SecretConfig'    = @{
            'secretIds'  = @{
                'serviceAccounts' = 'NDMIS_DFI_SERVICEACCOUNTS_PREPROD'
                'bodsPasswords'   = 'delius-mis-preprod-oracle-psd-db-application-passwords'
                'bodsConfig'      = 'NDMIS_DFI_SERVICEACCOUNTS_PREPROD'
                'sysDbSecrets'    = 'delius-mis-preprod-oracle-psd-db-application-passwords'
                'audDbSecrets'    = 'delius-mis-preprod-oracle-psd-db-application-passwords'
            }
            'secretKeys' = @{
                'bodsAdminPassword'      = 'DFI_IPS_Administrator_LCMS_Administrator'
                'ipsProductKey'          = 'ips_product_key'
                'dataServicesProductKey' = 'data_services_product_key'
                'bodsSubversionPassword' = 'bods_subversion_password'
                'serviceUserPassword'    = 'SVC_DFI_NDL'
                'sysDbUserPassword'      = 'dfi_mod_ipscms'
                'audDbUserPassword'      = 'dfi_mod_ipsaud'
            }
        }
        
        'SiaNodeName'     = 'NDLMODPP101'
    }
    
    'delius-mis-production'  = @{
        # Add production-specific overrides here
    }
}