# suppress PSScript Analyzer warning - variable not in use.
[Diagnostics.CodeAnalysis.SuppressMessage('PSUseDeclaredVarsMoreThanAssignments', 'GlobalConfig')]
param()

$GlobalConfig = @{
    'all'                                    = @{
        'WindowsClientS3Bucket'      = 'mod-platform-image-artefact-bucket20230203091453221500000001'
        'WindowsClientS3Folder'      = 'hmpps/onr'
        'Oracle19c64bitClientS3File' = 'WINDOWS.X64_193000_client.zip'
        'ORACLE_19C_HOME'            = 'E:\app\oracle\product\19.0.0\client_1'
        'ORACLE_BASE'                = 'E:\app\oracle'
        'IPSS3File'                  = '51054935.ZIP' # Information Platform Services 4.2 SP9 Patch 0
        'DataServicesS3File'         = 'DS4214P_11-20011165.exe' # Data Services 4.2 SP14 Patch 11
        'LINK_DIR'                   = 'E:\SAP BusinessObjects\Data Services'
        'BIP_INSTALL_DIR'            = 'E:\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0'
        'RegistryPath'               = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon'
        'LegalNoticeCaption'         = 'IMPORTANT'
        'LegalNoticeText'            = 'This system is restricted to authorized users only. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information'
        'WorkingDirectory'           = 'E:\Software'
        'AppDirectory'               = 'E:\App'
    }
    'oasys-national-reporting-development'   = @{

    }
    'oasys-national-reporting-test'          = @{
        'sysDbName'              = 'T2BOSYS'
        'audDbName'              = 'T2BOAUD'
        'tnsorafile'             = 'ONR\tnsnames_T2_BODS.ora'
        'cmsPrimaryNode'         = 't2-onr-bods-1'
        'cmsSecondaryNode'       = 't2-onr-bods-2'
        'serviceUser'            = 'svc_nart'
        'serviceUserPath'        = 'OU=Service,OU=Users,OU=NOMS RBAC,DC=AZURE,DC=NOMS,DC=ROOT'
        'nartComputersOU'        = 'OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT'
        'serviceUserDescription' = 'Onr BODS service user for AWS in AZURE domain'
        'domain'                 = 'AZURE'
    }
    'oasys-national-reporting-preproduction' = @{
        'sysDbName'              = 'PPBOSYS'
        'audDbName'              = 'PPBOAUD'
        'tnsorafile'             = 'ONR\tnsnames_PP_BODS.ora'
        'cmsPrimaryNode'         = 'pp-onr-bods-1'
        'cmsSecondaryNode'       = 'pp-onr-bods-2'
        'serviceUser'            = 'svc_nart'
        'serviceUserPath'        = 'OU=SERVICE_ACCOUNTS,OU=RBAC,DC=AZURE,DC=HMPP,DC=ROOT'
        'nartComputersOU'        = 'OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT'
        'serviceUserDescription' = 'Onr BODS service user for AWS in HMPP domain'
        'domain'                 = 'HMPP'
    }
    'oasys-national-reporting-production'    = @{
        'sysDbName'              = 'PDBOSYS'
        'audDbName'              = 'PDBOAUD'
        'tnsorafile'             = 'ONR\tnsnames_PD_BODS.ora'
        'cmsPrimaryNode'         = 'pd-onr-bods-1'
        'cmsSecondaryNode'       = 'pd-onr-bods-2'
        'serviceUser'            = 'svc_nart'
        'serviceUserPath'        = 'OU=SERVICE_ACCOUNTS,OU=RBAC,DC=AZURE,DC=HMPP,DC=ROOT'
        'nartComputersOU'        = 'OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT'
        'serviceUserDescription' = 'Onr BODS service user for AWS in HMPP domain'
        'domain'                 = 'HMPP'
    }
}