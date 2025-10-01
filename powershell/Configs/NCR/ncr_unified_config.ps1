# NCR Unified Configuration
# This config uses the unified template with NCR-specific overrides

# suppress PSScript Analyzer warning - variable not in use.
[Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssignments', 'ApplicationConfig')]
param()

$ApplicationConfig = @{
    'all'                                    = @{
        # Override base template for NCR-specific settings
        'WindowsClientS3Folder' = 'hmpps/ncr'
        'IPSS3File'             = '51054521.ZIP'  # Information Platform Services 4.2 SP8 Patch 1
        'DataServicesS3File'    = '51054517_4.ZIP'  # Data Services 4.2 SP 14 as per Azure machines for NCR BODS
        
        # NCR uses E:\ drive structure (same as ONR, different from MISDis D:\)
        'ORACLE_19C_HOME'       = 'E:\app\oracle\product\19.0.0\client_1'
        'ORACLE_BASE'           = 'E:\app\oracle'
        'LINK_DIR'              = 'E:\SAP BusinessObjects\Data Services'
        'BIP_INSTALL_DIR'       = 'E:\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0'
        'WorkingDirectory'      = 'E:\Software'
        'AppDirectory'          = 'E:\App'
        'dscommondir'           = 'F:\BODS_COMMON_DIR'
        
        # NCR uses standard secret pattern (not misdis)
        'SecretConfig'          = @{
            'secretPattern'  = 'standard'
            'secretMappings' = @{
                'bodsSecretName'  = '/sap/bods/{dbenv}/passwords'
                'bodsConfigName'  = '/sap/bods/{dbenv}/config'
                'sysDbSecretName' = '/oracle/database/{sysDbName}/passwords'
                'audDbSecretName' = '/oracle/database/{audDbName}/passwords'
            }
        }
        
        # NCR-specific database users (same as ONR)
        'DatabaseConfig'        = @{
            'sysDbUser' = 'bods_ips_system_owner'
            'audDbUser' = 'bods_ips_audit_owner'
        }
        
        # NCR-specific service configuration
        'ServiceConfig'         = @{
            'serviceUser'            = 'svc_nart'
            'serviceUserDescription' = 'NART service user for AWS in AZURE domain'
        }
    }
    
    'nomis-combined-reporting-development'   = @{
        # Development environment overrides - database names not yet configured
        'TnsConfig'     = @{
            'tnsOraFile' = 'NCR\tnsnames_DEV_BODS.ora'  # Assuming development TNS file
        }
        
        'ServiceConfig' = @{
            'serviceUserPath' = 'OU=Service,OU=Users,OU=NOMS RBAC,DC=AZURE,DC=NOMS,DC=ROOT'
            'domain'          = 'AZURE'
        }
        
        'NodeConfig'    = @{
            'nartComputersOU' = 'OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT'
        }
    }
    
    'nomis-combined-reporting-test'          = @{
        # Database names not yet configured in original config
        'DatabaseConfig' = @{
            'sysDbName' = ''  # To be configured
            'audDbName' = ''  # To be configured
        }
        
        'NodeConfig'     = @{
            'cmsPrimaryNode'   = 't1-ncr-bods-1'
            'cmsSecondaryNode' = 't1-ncr-bods-2'  # Commented out in original
            'nartComputersOU'  = 'OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT'
        }
        
        'ServiceConfig'  = @{
            'serviceUserPath' = 'OU=Service,OU=Users,OU=NOMS RBAC,DC=AZURE,DC=NOMS,DC=ROOT'
            'domain'          = 'AZURE'
        }
        
        'TnsConfig'      = @{
            'tnsOraFile' = 'NCR\tnsnames_T1_BODS.ora'
        }
    }
    
    'nomis-combined-reporting-preproduction' = @{
        # Database names not yet configured in original config
        'DatabaseConfig' = @{
            'sysDbName' = ''  # To be configured
            'audDbName' = ''  # To be configured
        }
        
        'NodeConfig'     = @{
            'cmsPrimaryNode'   = 'pp-ncr-bods-1'
            'cmsSecondaryNode' = 'pp-ncr-bods-2'  # Commented out in original
            'nartComputersOU'  = 'OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT'
        }
        
        'ServiceConfig'  = @{
            'serviceUserPath' = 'OU=SERVICE_ACCOUNTS,OU=RBAC,DC=AZURE,DC=HMPP,DC=ROOT'
            'domain'          = 'HMPP'
        }
        
        'TnsConfig'      = @{
            'tnsOraFile' = 'NCR\tnsnames_PP_BODS.ora'
        }
    }
    
    'nomis-combined-reporting-production'    = @{
        # Database names not yet configured in original config
        'DatabaseConfig' = @{
            'sysDbName' = ''  # To be configured
            'audDbName' = ''  # To be configured
        }
        
        'NodeConfig'     = @{
            'cmsPrimaryNode'   = 'pd-ncr-bods-1'  # Commented out in original
            'cmsSecondaryNode' = 'pd-ncr-bods-2'  # Commented out in original
            'nartComputersOU'  = 'OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT'
        }
        
        'ServiceConfig'  = @{
            'serviceUserPath' = 'OU=SERVICE_ACCOUNTS,OU=RBAC,DC=AZURE,DC=HMPP,DC=ROOT'
            'domain'          = 'HMPP'
        }
        
        'TnsConfig'      = @{
            'tnsOraFile' = 'NCR\tnsnames_PD_BODS.ora'  # Commented out in original
        }
    }
}