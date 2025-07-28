# MISDis Unified Configuration
# This config uses the unified template with MISDis-specific overrides

# suppress PSScript Analyzer warning - variable not in use.
[Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssignments', 'ApplicationConfig')]
param()  

$ApplicationConfig = @{ 
    'all'                      = @{
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
        'dscommondir'           = 'D:\DSCommon'
        
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
    
    'delius-mis-development'   = @{
        'EnvironmentName' = 'delius-mis-development'
        
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
            'serviceUser' = 'SVC_DIS_NDL'
            'domain'      = 'delius-mis-dev'
        }
        
        # MISDis-specific settings for development
        'SiaNodeName'     = 'NDLMODDFI101'
    }
    
    'delius-mis-preproduction' = @{
        # Legacy config for backward compatibility - defaults to stage cluster
        'DatabaseConfig' = @{
            'sysDbName' = 'DMPDSD'
            'audDbName' = 'DMPDSD'
            'sysDbUser' = 'dfi_mod_ipscms'
            'audDbUser' = 'dfi_mod_ipsaud'
        }
        
        'NodeConfig'     = @{
            'cmsPrimaryNode'   = 'delius-mis-stage-dfi-1'
            'cmsSecondaryNode' = 'delius-mis-stage-dfi-2'
        }
        
        'ServiceConfig'  = @{
            'serviceUser' = 'SVC_DIS_NDL'
            'domain'      = 'delius-mis-preprod'
        }
        
        'SiaNodeName'    = 'NDLMODSTG101'
    }
    
    # Cluster-specific configurations (keyed by primary node name)
    'delius-mis-stage-dfi-1'   = @{
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
        
        'SiaNodeName'     = 'NDLMODSTG101'
    }
    
    'delius-mis-pp-dfi-1'      = @{
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
        
        'SiaNodeName'     = 'NDLMODPP101'
    }
    
    'delius-mis-production'    = @{
        # Add production-specific overrides here
    }
}