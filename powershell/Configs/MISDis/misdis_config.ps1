$GlobalConfig = @{
    "all" = @{
        "WorkingDirectory" = "D:\Software" # Differs from ONR / NCR
        "WindowsClientS3Bucket"      = "mod-platform-image-artefact-bucket20230203091453221500000001"
        "WindowsClientS3Folder"      = "hmpps/mis"
        "IPSS3File"                  = "IPS4304P_900-70002778.EXE" # Information Platform Services 4.3 SP9 Patch 7
        "DataServicesS3File"         = "DS4303P_4-80007397.EXE" # Data Services 4.3 SP3 Patch 4
        "LINK_DIR"                   = "D:\BusinessObjects\Data Services"
        "BIP_INSTALL_DIR"            = "D:\BusinessObjects\SAP BusinessObjects Enterprise XI 4.0"
        "AppDirectory"               = "D:\App"
        "dscommondir"                = "D:\DSCommon"
    }
    "delius-mis-development" = @{
        "sysDbName"              = "DMDDSD"
        "audDbName"              = "DMDDSD"
        "cmsPrimaryNode"         = "ndmis-dev-dfi-1"
        "serviceUser"            = "SVC_DIS_NDL" # Only used for dataservices install
        "Domain"                 = "delius-mis-dev"
    }
    "delius-mis-preproduction" = @{
    }
    "delius-mis-production" = @{
    }
}
