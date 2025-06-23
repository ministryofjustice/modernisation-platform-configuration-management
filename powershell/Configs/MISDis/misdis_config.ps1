$GlobalConfig = @{
    "all" = @{
        "WorkingDirectory" = "D:\Software" # Differs from ONR / NCR
        "WindowsClientS3Bucket"      = "mod-platform-image-artefact-bucket20230203091453221500000001"
        "WindowsClientS3Folder"      = "hmpps/mis"
        "ORACLE_19C_HOME"            = "D:\app\oracle\product\19.0.0\client_1"
        "ORACLE_BASE"                = "D:\app\oracle"
        "IPSS3File"                  = "IPS4304P_900-70002778.EXE" # Information Platform Services 4.3 SP9 Patch 7
        "DataServicesS3File"         = "DS4303P_4-80007397.EXE" # Data Services 4.3 SP3 Patch 4
        "LINK_DIR"                   = "D:\SAP BusinessObjects\Data Services"
        "BIP_INSTALL_DIR"            = "D:\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0"
        "AppDirectory"               = "D:\App"
    }
    "delius-mis-development" = @{
        "sysDbName"              = "T2BOSYS" # FIXME: incorrect
        "audDbName"              = "T2BOAUD" # FIXME: incorrect
        "tnsorafile"             = "MISDis\tnsnames_T2_BODS.ora" # FIXME: incorrect
        "cmsPrimaryNode"         = "t2-onr-bods-1" # FIXME: incorrect
        "cmsSecondaryNode"       = "t2-onr-bods-2" # FIXME: incorrect
        "serviceUser"            = "SVC_DIS_NDL"
        "serviceUserPath"        = "OU=Service,OU=Users,OU=NOMS RBAC,DC=AZURE,DC=NOMS,DC=ROOT" # FIXME: incorrect
        "nartComputersOU"        = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT" # FIXME: incorrect
        "serviceUserDescription" = "Service User for NDMIS"
        "domain"                 = "AZURE" # FIXME:
    }
    "delius-mis-preproduction" = @{
    }
    "delius-mis-production" = @{
    }
}
