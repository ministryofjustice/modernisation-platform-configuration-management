$GlobalConfig = @{
    "all"                                    = @{
        "WindowsClientS3Bucket"      = "mod-platform-image-artefact-bucket20230203091453221500000001"
        "WindowsClientS3Folder"      = "hmpps/ncr"
        "Oracle19c64bitClientS3File" = "WINDOWS.X64_193000_client.zip"
        "ORACLE_19C_HOME"            = "E:\app\oracle\product\19.0.0\client_1"
        "ORACLE_BASE"                = "E:\app\oracle"
        "IPSS3File"                  = "51054521.ZIP" # Information Platform Services 4.2 SP8 Patch 1
        "DataServicesS3File"         = "51054517_4.ZIP" # Data Services 4.2 SP 14 as per Azure machines for NCR BODS
        "LINK_DIR"                   = "E:\SAP BusinessObjects\Data Services"
        "BIP_INSTALL_DIR"            = "E:\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0"
        "RegistryPath"               = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon"
        "LegalNoticeCaption"         = "IMPORTANT"
        "LegalNoticeText"            = "This system is restricted to authorized users only. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information"
        "WorkingDirectory"           = "E:\Software"
        "AppDirectory"               = "E:\App"
    }
    "nomis-combined-reporting-development"   = @{
    }
    "nomis-combined-reporting-test"          = @{
        # "sysDbName"       = ""
        # "audDbName"       = ""
        "tnsorafile"             = "NCR\tnsnames_T1_BODS.ora"
        "cmsPrimaryNode"         = "t1-ncr-bods-1"
        # "cmsPrimaryNode"     = "t1-tst-bods-asg" # Use this value when testing
        # "cmsSecondaryNode" = "t1-ncr-bods-2"
        "serviceUser"            = "svc_nart"
        "serviceUserPath"        = "OU=Service,OU=Users,OU=NOMS RBAC,DC=AZURE,DC=NOMS,DC=ROOT"
        "nartComputersOU"        = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
        "serviceUserDescription" = "NART service user for AWS in AZURE domain"
        "domain"                 = "AZURE"
    }
    "nomis-combined-reporting-preproduction" = @{
        # "sysDbName"       = ""
        # "audDbName"       = ""
        "tnsorafile"             = "NCR\tnsnames_PP_BODS.ora"
        "cmsPrimaryNode"         = "pp-ncr-bods-1"
        # "cmsSecondaryNode" = "pp-ncr-bods-2"
        "serviceUser"            = "svc_nart"
        "serviceUserPath"        = "OU=SERVICE_ACCOUNTS,OU=RBAC,DC=AZURE,DC=HMPP,DC=ROOT"
        "nartComputersOU"        = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT"
        "serviceUserDescription" = "NART service user for AWS in HMPP domain"
        "domain"                 = "HMPP"
    }
    "nomis-combined-reporting-production"    = @{
        # "sysDbName"       = ""
        # "audDbName"       = ""
        # "tnsorafile"             = "NCR\tnsnames_PD_BODS.ora"
        # "cmsPrimaryNode"         = "pd-ncr-bods-1"
        # "cmsSecondaryNode" = "pd-ncr-bods-2"
        "serviceUser"            = "svc_nart"
        "serviceUserPath"        = "OU=SERVICE_ACCOUNTS,OU=RBAC,DC=AZURE,DC=HMPP,DC=ROOT"
        "nartComputersOU"        = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT"
        "serviceUserDescription" = "NART service user for AWS in HMPP domain"
        "domain"                 = "HMPP"
    }
}