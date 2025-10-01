# ONR Unified Configuration
# This config uses the unified template with ONR-specific overrides

# suppress PSScript Analyzer warning - variable not in use.
[Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssignments', 'ApplicationConfig')]
param()

$ApplicationConfig = @{
    'all'                                    = @{
        # Override base template for ONR-specific settings
        'WindowsClientS3Folder' = 'hmpps/onr'
        'IPSS3File'             = '51054935.ZIP'  # Information Platform Services 4.2 SP9 Patch 0
        'DataServicesS3File'    = 'DS4214P_11-20011165.exe'  # Data Services 4.2 SP14 Patch 11
        
        # ONR uses E:\ drive structure (different from MISDis D:\)
        'ORACLE_19C_HOME'       = 'E:\app\oracle\product\19.0.0\client_1'
        'ORACLE_BASE'           = 'E:\app\oracle'
        'LINK_DIR'              = 'E:\SAP BusinessObjects\Data Services'
        'BIP_INSTALL_DIR'       = 'E:\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0'
        'WorkingDirectory'      = 'E:\Software'
        'AppDirectory'          = 'E:\App'
        'dscommondir'           = 'F:\BODS_COMMON_DIR'
        
        # ONR uses standard secret pattern (not misdis)
        'SecretConfig'          = @{
            'secretPattern'  = 'standard'
            'secretMappings' = @{
                'bodsSecretName'  = '/sap/bods/{dbenv}/passwords'
                'bodsConfigName'  = '/sap/bods/{dbenv}/config'
                'sysDbSecretName' = '/oracle/database/{sysDbName}/passwords'
                'audDbSecretName' = '/oracle/database/{audDbName}/passwords'
            }
        }
        
        # ONR-specific database users
        'DatabaseConfig'        = @{
            'sysDbUser' = 'bods_ips_system_owner'
            'audDbUser' = 'bods_ips_audit_owner'
        }
        
        # ONR-specific service configuration
        'ServiceConfig'         = @{
            'serviceUser'            = 'svc_nart'
            'serviceUserDescription' = 'Onr BODS service user for AWS in AZURE domain'
        }
    }
    
    'oasys-national-reporting-development'   = @{}
    
    'oasys-national-reporting-test'          = @{
        # Legacy config for backward compatibility - defaults to first cluster
        'DatabaseConfig' = @{
            'sysDbName' = 'T2BOSYS'
            'audDbName' = 'T2BOAUD'
        }
        
        'NodeConfig'     = @{
            'cmsPrimaryNode'   = 't2-onr-bods-1'
            'cmsSecondaryNode' = 't2-onr-bods-2'
            'nartComputersOU'  = 'OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT'
        }
        
        'ServiceConfig'  = @{
            'serviceUserPath' = 'OU=Service,OU=Users,OU=NOMS RBAC,DC=AZURE,DC=NOMS,DC=ROOT'
            'domain'          = 'AZURE'
        }
        
        'TnsConfig'      = @{
            'tnsOraFile' = 'ONR\tnsnames_T2_BODS.ora'
        }
    }
    
    'oasys-national-reporting-preproduction' = @{
        'DatabaseConfig' = @{
            'sysDbName' = 'PPBOSYS'
            'audDbName' = 'PPBOAUD'
        }
        
        'NodeConfig'     = @{
            'cmsPrimaryNode'   = 'pp-onr-bods-1'
            'cmsSecondaryNode' = 'pp-onr-bods-2'
            'nartComputersOU'  = 'OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT'
        }
        
        'ServiceConfig'  = @{
            'serviceUserPath' = 'OU=SERVICE_ACCOUNTS,OU=RBAC,DC=AZURE,DC=HMPP,DC=ROOT'
            'domain'          = 'HMPP'
        }
        
        'TnsConfig'      = @{
            'tnsOraFile' = 'ONR\tnsnames_PP_BODS.ora'
        }
    }
    
    'oasys-national-reporting-production'    = @{
        'DatabaseConfig' = @{
            'sysDbName' = 'PDBOSYS'
            'audDbName' = 'PDBOAUD'
        }
        
        'NodeConfig'     = @{
            'cmsPrimaryNode'   = 'pd-onr-bods-1'
            'cmsSecondaryNode' = 'pd-onr-bods-2'
            'nartComputersOU'  = 'OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT'
        }
        
        'ServiceConfig'  = @{
            'serviceUserPath' = 'OU=SERVICE_ACCOUNTS,OU=RBAC,DC=AZURE,DC=HMPP,DC=ROOT'
            'domain'          = 'HMPP'
        }
        
        'TnsConfig'      = @{
            'tnsOraFile' = 'ONR\tnsnames_PD_BODS.ora'
        }
    }
}