# Unified Configuration Template for BODS Environments
# This template provides a consistent structure across ONR, NCR, and MISDis

# suppress PSScript Analyzer warning - variable not in use.
[Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssignments', 'UnifiedConfigTemplate')]
param()

$UnifiedConfigTemplate = @{
    'all' = @{
        # S3 Configuration
        'WindowsClientS3Bucket'      = 'mod-platform-image-artefact-bucket20230203091453221500000001'
        'WindowsClientS3Folder'      = '' # Override per application
        
        # Installer Files
        'Oracle19c64bitClientS3File' = 'WINDOWS.X64_193000_client.zip'
        'IPSS3File'                  = '' # Override per application/version
        'DataServicesS3File'         = '' # Override per application/version
        
        # Oracle Configuration
        'ORACLE_19C_HOME'            = 'E:\app\oracle\product\19.0.0\client_1'
        'ORACLE_BASE'                = 'E:\app\oracle'
        
        # Installation Directories
        'LINK_DIR'                   = 'E:\SAP BusinessObjects\Data Services'
        'BIP_INSTALL_DIR'            = 'E:\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0'
        'WorkingDirectory'           = 'E:\Software'
        'AppDirectory'               = 'E:\App'
        'dscommondir'                = 'F:\BODS_COMMON_DIR'
        
        # Registry Configuration
        'RegistryPath'               = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon'
        'LegalNoticeCaption'         = 'IMPORTANT'
        'LegalNoticeText'            = 'This system is restricted to authorized users only. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information'
        
        # Database Configuration (defaults)
        'DatabaseConfig'             = @{
            'sysDbName' = ''
            'audDbName' = ''
            'sysDbUser' = 'bods_ips_system_owner'
            'audDbUser' = 'bods_ips_audit_owner'
        }
        
        # Service Configuration
        'ServiceConfig'              = @{
            'serviceUser'            = 'svc_nart'
            'serviceUserPath'        = ''
            'serviceUserDescription' = ''
            'domain'                 = ''
        }
        
        # Node Configuration
        'NodeConfig'                 = @{
            'cmsPrimaryNode'   = ''
            'cmsSecondaryNode' = ''
            'nartComputersOU'  = ''
        }
        
        # Secret Configuration
        'SecretConfig'               = @{
            'secretPattern'  = 'standard' # "standard", "misdis", "custom"
            'secretMappings' = @{
                'bodsSecretName'  = '/sap/bods/{dbenv}/passwords'
                'bodsConfigName'  = '/sap/bods/{dbenv}/config'
                'sysDbSecretName' = '/oracle/database/{sysDbName}/passwords'
                'audDbSecretName' = '/oracle/database/{audDbName}/passwords'
            }
        }
        
        # Response File Templates - version-specific
        'ResponseFileTemplates'      = @{
            'IPSPrimary'              = 'IPS_Primary_Template.ini'      # Version 4.2
            'IPSSecondary'            = 'IPS_Secondary_Template.ini'   # Version 4.2
            'DataServicesPrimary'     = 'DataServices_Primary_Template.ini'     # Version 4.2
            'DataServicesSecondary'   = 'DataServices_Secondary_Template.ini' # Version 4.2
            'IPSPrimary43'            = 'IPS_Primary_Template_43.ini'      # Version 4.3
            'IPSSecondary43'          = 'IPS_Secondary_Template_43.ini'   # Version 4.3
            'DataServicesPrimary43'   = 'DataServices_Primary_Template_43.ini'     # Version 4.3
            'DataServicesSecondary43' = 'DataServices_Secondary_Template_43.ini' # Version 4.3
        }
        
        # TNS Configuration
        'TnsConfig'                  = @{
            'tnsOraFile' = ''
        }
    }
}

# Function to merge environment-specific config with template
function Merge-ConfigWithTemplate {
    param(
        [hashtable]$Template,
        [hashtable]$EnvironmentConfig
    )
    
    $mergedConfig = $Template.Clone()
    
    foreach ($key in $EnvironmentConfig.Keys) {
        if ($mergedConfig.ContainsKey($key) -and $mergedConfig[$key] -is [hashtable] -and $EnvironmentConfig[$key] -is [hashtable]) {
            # Merge nested hashtables
            foreach ($nestedKey in $EnvironmentConfig[$key].Keys) {
                $mergedConfig[$key][$nestedKey] = $EnvironmentConfig[$key][$nestedKey]
            }
        }
        else {
            $mergedConfig[$key] = $EnvironmentConfig[$key]
        }
    }
    
    return $mergedConfig
}