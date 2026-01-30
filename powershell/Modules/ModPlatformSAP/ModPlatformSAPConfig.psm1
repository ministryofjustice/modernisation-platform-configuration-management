function Get-ModPlatformSAPConfig {
<#
.SYNOPSIS
    Retrieve appropriate SAP config for the given Modernisation Platform environment.

.DESCRIPTION
    Derived from EC2 tags (environment-name and Name).
    EC2 requires permissions to get tags and the aws cli.

.OUTPUTS
    HashTable
#>

  [CmdletBinding()]
  param (
    [string]$DomainNameFQDN
  )

  $ModPlatformSAPConfigsByEnvironment = @{
    'hmpps-domain-services-development' = @{
      'dev-jump2022-1' = @{
        InstallPackages = @{
          Client = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/ncr-packages'
            S3File        = 'BIPLATCLNT4304P_500-70005711.EXE'
            WorkingDir    = 'C:\Software'             # Download installer here
            ExtractDir    = 'C:\Software\BIP43'
            SkipIfPresent = 'C:\Software\BIP43\setup.exe'
          }
        }
        Variables = @{
          InstallDir     = 'C:\Program Files (x86)\SAP BusinessObjects'
        }
        Secrets = @{}
      }
    }
    'hmpps-domain-services-test' = @{
      't1-jump2022-1' = @{
        InstallPackages = @{
          Client = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/ncr-packages'
            S3File        = 'BIPLATCLNT4304P_500-70005711.EXE'
            WorkingDir    = 'C:\Software'             # Download installer here
            ExtractDir    = 'C:\Software\BIP43'
            SkipIfPresent = 'C:\Software\BIP43\setup.exe'
          }
          FlexiLogReader = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/sap/FlexiLogReader'
            S3File        = 'FlexiLogReader64.zip'
            S3Files       = @('FlexiLogReader64.z01', 'FlexiLogReader64.z02', 'FlexiLogReader64.z03', 'FlexiLogReader64.z04')
            WorkingDir    = 'C:\Software'             # Download installer here
            ExtractDir    = 'C:\Software'
            SkipIfPresent = 'C:\Software\FlexiLogReader64\FlexiLogReader64.exe'
          }
        }
        Variables = @{
          InstallDir     = 'C:\Program Files (x86)\SAP BusinessObjects'
        }
        Secrets = @{}
      }
    }
    'hmpps-domain-services-preproduction' = @{
      'pp-jump2022-1' = @{
        InstallPackages = @{
          Client = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/ncr-packages'
            S3File        = 'BIPLATCLNT4304P_500-70005711.EXE'
            WorkingDir    = 'C:\Software'             # Download installer here
            ExtractDir    = 'C:\Software\BIP43'
            SkipIfPresent = 'C:\Software\BIP43\setup.exe'
          }
        }
        Variables = @{
          InstallDir     = 'C:\Program Files (x86)\SAP BusinessObjects'
        }
        Secrets = @{}
      }
    }
    'hmpps-domain-services-production' = @{
      'pd-jump2022-1' = @{
        InstallPackages = @{
          Client = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/ncr-packages'
            S3File        = 'BIPLATCLNT4304P_500-70005711.EXE'
            WorkingDir    = 'C:\Software'             # Download installer here
            ExtractDir    = 'C:\Software\BIP43'
            SkipIfPresent = 'C:\Software\BIP43\setup.exe'
          }
        }
        Variables = @{
          InstallDir     = 'C:\Program Files (x86)\SAP BusinessObjects'
        }
        Secrets = @{}
      }
    }
    'oasys-national-reporting-test' = @{
      't2-onr-bods' = @{
        InstallPackages = @{
          Ips = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/onr'
            S3File        = '51054935.ZIP'            # Information Platform Services 4.2 SP9 Patch 0
            WorkingDir    = 'E:\Software'             # Download installer here
            ExtractDir    = 'E:\Software\IPS_42_SP9_P0'
            SkipIfPresent = 'E:\Software\IPS_42_SP9_P0\setup.exe'
          }
          DataServices  = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/mis'
            S3File        = 'DS4214P_11-20011165.EXE' # Data Services 4.2 SP14 Patch 11
            WorkingDir    = 'E:\Software'             # Download installer here
            ExtractDir    = 'E:\Software\DS4214P_11-20011165'
            SkipIfPresent = 'E:\Software\DS4214P_11-20011165\setup.exe'
          }
        }
        Variables = @{
          InstallDir     = 'E:\SAP BusinessObjects'
          DSCommonDir    = 'F:\BODS_COMMON_DIR'
          LinkDir        = 'E:\SAP BusinessObjects\Data Services'
          SysDbName      = 'T2BOSYS'
          SysDbUser      = 'bods_ips_system_owner'
          AudDbName      = 'T2BOAUD'
          AudDbUser      = 'bods_ips_audit_owner'
          SiaNameBase    = 'T2ONRBODS'
          ServiceUser    = 'AZURE\svc_nart'
          DomainNameFQDN = 'azure.noms.root'
        }
        Secrets = @{
          ClusterKey = @{
            SecretName = '/sap/bods/t2/config'
            Key        = 'bods_cluster_key'
          }
          IpsProductKey = @{
            SecretName = '/sap/bods/t2/config'
            Key        = 'ips_product_key'
          }
          DataServicesProductKey = @{
            SecretName = '/sap/bods/t2/config'
            Key        = 'data_services_product_key'
          }
          SysDbPassword = @{
            SecretName = '/oracle/database/T2BOSYS/passwords'
            Key        = 'bods_ips_system_owner'
          }
          AudDbPassword = @{
            SecretName = '/oracle/database/T2BOAUD/passwords'
            Key        = 'bods_ips_audit_owner'
          }
          CmsAdminPassword = @{
            SecretName = '/sap/bods/t2/passwords'
            Key        = 'bods_admin_password'
          }
          ServiceUserPassword = @{
            SecretName = '/sap/bods/t2/passwords'
            Key        = 'svc_nart'
          }
          CmsPrimaryHostname = @{
            SecretName = '/sap/bods/t2/config'
            Key        = 'cms_primary_hostname'
          }
        }
      }
    }
    'oasys-national-reporting-preproduction' = @{
      'pp-onr-bods' = @{
        InstallPackages = @{
          Ips = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/onr'
            S3File        = '51054935.ZIP'            # Information Platform Services 4.2 SP9 Patch 0
            WorkingDir    = 'E:\Software'             # Download installer here
            ExtractDir    = 'E:\Software\IPS_42_SP9_P0'
            SkipIfPresent = 'E:\Software\IPS_42_SP9_P0\setup.exe'
          }
          DataServices  = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/mis'
            S3File        = 'DS4214P_11-20011165.EXE' # Data Services 4.2 SP14 Patch 11
            WorkingDir    = 'E:\Software'             # Download installer here
            ExtractDir    = 'E:\Software\DS4214P_11-20011165'
            SkipIfPresent = 'E:\Software\DS4214P_11-20011165\setup.exe'
          }
        }
        Variables = @{
          InstallDir     = 'E:\SAP BusinessObjects'
          DSCommonDir    = 'F:\BODS_COMMON_DIR'
          LinkDir        = 'E:\SAP BusinessObjects\Data Services'
          SysDbName      = 'PPBOSYS'
          SysDbUser      = 'bods_ips_system_owner'
          AudDbName      = 'PPBOAUD'
          AudDbUser      = 'bods_ips_audit_owner'
          SiaNameBase    = 'PPONRBODS'
          ServiceUser    = 'HMPP\svc_nart'
          DomainNameFQDN = 'azure.hmpp.root'
        }
        Secrets = @{
          ClusterKey = @{
            SecretName = '/sap/bods/pp/config'
            Key        = 'bods_cluster_key'
          }
          IpsProductKey = @{
            SecretName = '/sap/bods/pp/config'
            Key        = 'ips_product_key'
          }
          DataServicesProductKey = @{
            SecretName = '/sap/bods/pp/config'
            Key        = 'data_services_product_key'
          }
          SysDbPassword = @{
            SecretName = '/oracle/database/PPBOSYS/passwords'
            Key        = 'bods_ips_system_owner'
          }
          AudDbPassword = @{
            SecretName = '/oracle/database/PPBOAUD/passwords'
            Key        = 'bods_ips_audit_owner'
          }
          CmsAdminPassword = @{
            SecretName = '/sap/bods/pp/passwords'
            Key        = 'bods_admin_password'
          }
          ServiceUserPassword = @{
            SecretName = '/sap/bods/pp/passwords'
            Key        = 'svc_pp_onr_bods'
          }
          CmsPrimaryHostname = @{
            SecretName = '/sap/bods/pp/config'
            Key        = 'cms_primary_hostname'
          }
        }
      }
    }
    'oasys-national-reporting-production' = @{
      'pd-onr-bods' = @{
        InstallPackages = @{
          Ips = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/onr'
            S3File        = '51054935.ZIP'            # Information Platform Services 4.2 SP9 Patch 0
            WorkingDir    = 'E:\Software'             # Download installer here
            ExtractDir    = 'E:\Software\IPS_42_SP9_P0'
            SkipIfPresent = 'E:\Software\IPS_42_SP9_P0\setup.exe'
          }
          DataServices  = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/mis'
            S3File        = 'DS4214P_11-20011165.EXE' # Data Services 4.2 SP14 Patch 11
            WorkingDir    = 'E:\Software'             # Download installer here
            ExtractDir    = 'E:\Software\DS4214P_11-20011165'
            SkipIfPresent = 'E:\Software\DS4214P_11-20011165\setup.exe'
          }
        }
        Variables = @{
          InstallDir     = 'E:\SAP BusinessObjects'
          DSCommonDir    = 'F:\BODS_COMMON_DIR'
          LinkDir        = 'E:\SAP BusinessObjects\Data Services'
          SysDbName      = 'PDBOSYS'
          SysDbUser      = 'bods_ips_system_owner'
          AudDbName      = 'PDBOAUD'
          AudDbUser      = 'bods_ips_audit_owner'
          SiaNameBase    = 'PDONRBODS'
          ServiceUser    = 'HMPP\svc_nart'
          DomainNameFQDN = 'azure.hmpp.root'
        }
        Secrets = @{
          ClusterKey = @{
            SecretName = '/sap/bods/pd/config'
            Key        = 'bods_cluster_key'
          }
          IpsProductKey = @{
            SecretName = '/sap/bods/pd/config'
            Key        = 'ips_product_key'
          }
          DataServicesProductKey = @{
            SecretName = '/sap/bods/pd/config'
            Key        = 'data_services_product_key'
          }
          SysDbPassword = @{
            SecretName = '/oracle/database/PDBOSYS/passwords'
            Key        = 'bods_ips_system_owner'
          }
          AudDbPassword = @{
            SecretName = '/oracle/database/PDBOAUD/passwords'
            Key        = 'bods_ips_audit_owner'
          }
          CmsAdminPassword = @{
            SecretName = '/sap/bods/pd/passwords'
            Key        = 'bods_admin_password'
          }
          ServiceUserPassword = @{
            SecretName = '/sap/bods/pd/passwords'
            Key        = 'svc_pd_onr_bods'
          }
          CmsPrimaryHostname = @{
            SecretName = '/sap/bods/pd/config'
            Key        = 'cms_primary_hostname'
          }
        }
      }
    }
    'delius-mis-development' = @{
      'delius-mis-dev-dfi' = @{
        InstallPackages = @{
          Ips = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/mis'
            S3File        = 'IPS4304P_900-70002778.EXE'
            WorkingDir    = 'D:\Software'             # Download installer here
            ExtractDir    = 'D:\Software\IPS4304P_900-70002778'
            SkipIfPresent = 'D:\Software\IPS4304P_900-70002778\setup.exe'
          }
          DataServices  = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/mis'
            S3File        = 'DS4303P_4-80007397.EXE'
            WorkingDir    = 'D:\Software'             # Download installer here
            ExtractDir    = 'D:\Software\DS4303P_4-80007397'
            SkipIfPresent = 'D:\Software\DS4303P_4-80007397\setup.exe'
          }
          Client = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/ncr-packages'
            S3File        = 'BIPLATCLNT4304P_500-70005711.EXE'
            WorkingDir    = 'D:\Software'             # Download installer here
            ExtractDir    = 'D:\Software\BIPLATCLNT4304P_500-70005711'
            SkipIfPresent = 'D:\Software\BIPLATCLNT4304P_500-70005711\setup.exe'
          }
        }
        Variables = @{
          InstallDir     = 'D:\BusinessObjects'
          DSCommonDir    = 'D:\DSCommon'
          LinkDir        = 'D:\BusinessObjects\Data Services'
          SysDbName      = 'DMDDSD'
          SysDbUser      = 'dfi_mod_ipscms'
          AudDbName      = 'DMDDSD'
          AudDbUser      = 'dfi_mod_ipsaud'
          SiaNameBase    = 'NDLMODDFI10'
          ServiceUser    = 'delius-mis-dev\SVC_DFI_NDL'
          DomainNameFQDN = 'delius-mis-dev.internal'
        }
        Secrets = @{
          ClusterKey = @{
            SecretName = 'NDMIS_DFI_SERVICEACCOUNTS_DEV'
            Key        = 'dfi_cluster_key'
          }
          IpsProductKey = @{
            SecretName = 'NDMIS_DFI_SERVICEACCOUNTS_DEV'
            Key        = 'ips_product_key'
          }
          DataServicesProductKey = @{
            SecretName = 'NDMIS_DFI_SERVICEACCOUNTS_DEV'
            Key        = 'data_services_product_key'
          }
          SysDbPassword = @{
            SecretName = 'delius-mis-dev-oracle-dsd-db-application-passwords'
            Key        = 'dfi_mod_ipscms'
          }
          AudDbPassword = @{
            SecretName = 'delius-mis-dev-oracle-dsd-db-application-passwords'
            Key        = 'dfi_mod_ipsaud'
          }
          CmsAdminPassword = @{
            SecretName = 'NDMIS_DFI_SERVICEACCOUNTS_DEV'
            Key        = 'DFI_IPS_Administrator_LCMS_Administrator'
          }
          ServiceUserPassword = @{
            SecretName = 'NDMIS_DFI_SERVICEACCOUNTS_DEV'
            Key        = 'SVC_DFI_NDL'
          }
          CmsPrimaryHostname = @{
            SecretName = 'NDMIS_DFI_SERVICEACCOUNTS_DEV'
            Key        = 'dfi_cms_primary_hostname'
          }
        }
      }
      'delius-mis-dev-dis' = @{
        InstallPackages = @{
          Ips = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/mis'
            S3File        = 'IPS4304P_900-70002778.EXE'
            WorkingDir    = 'D:\Software'             # Download installer here
            ExtractDir    = 'D:\Software\IPS4304P_900-70002778'
            SkipIfPresent = 'D:\Software\IPS4304P_900-70002778\setup.exe'
          }
          DataServices  = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/mis'
            S3File        = 'DS4303P_4-80007397.EXE'
            WorkingDir    = 'D:\Software'             # Download installer here
            ExtractDir    = 'D:\Software\DS4303P_4-80007397'
            SkipIfPresent = 'D:\Software\DS4303P_4-80007397\setup.exe'
          }
        }
        Variables = @{
          InstallDir     = 'D:\BusinessObjects'
          DSCommonDir    = 'D:\DSCommon'
          LinkDir        = 'D:\BusinessObjects\Data Services'
          SysDbName      = 'DMDDXB'
          SysDbUser      = 'ipscms'
          AudDbName      = 'DMDDXB'
          AudDbUser      = 'ipsaud'
          SiaNameBase    = 'NDLMODDFI10'
          ServiceUser    = 'delius-mis-dev\SVC_DIS_NDL'
          DomainNameFQDN = 'delius-mis-dev.internal'
        }
        Secrets = @{
          ClusterKey = @{
            SecretName = 'delius-mis-dev-sap-dis-config'
            Key        = 'cluster_key'
          }
          IpsProductKey = @{
            SecretName = 'delius-mis-dev-sap-dis-config'
            Key        = 'ips_product_key'
          }
          DataServicesProductKey = @{
            SecretName = 'delius-mis-dev-sap-dis-config'
            Key        = 'data_services_product_key'
          }
          SysDbPassword = @{
            SecretName = 'delius-mis-dev-oracle-dsd-db-application-passwords'
            Key        = 'ipscms'
          }
          AudDbPassword = @{
            SecretName = 'delius-mis-dev-oracle-dsd-db-application-passwords'
            Key        = 'ipsaud'
          }
          CmsAdminPassword = @{
            SecretName = 'delius-mis-dev-sap-dis-passwords'
            Key        = 'Administrator'
          }
          ServiceUserPassword = @{
            SecretName = 'delius-mis-dev-sap-dis-passwords'
            Key        = 'SVC_DIS_NDL'
          }
          CmsPrimaryHostname = @{
            SecretName = 'delius-mis-dev-sap-dis-config'
            Key        = 'cms_primary_hostname'
          }
        }
      }
    }
    'delius-mis-preproduction' = @{
      'delius-mis-stage-dis' = @{
        InstallPackages = @{
          Ips = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/mis'
            S3File        = 'IPS4304P_900-70002778.EXE'
            WorkingDir    = 'D:\Software'             # Download installer here
            ExtractDir    = 'D:\Software\IPS4304P_900-70002778'
            SkipIfPresent = 'D:\Software\IPS4304P_900-70002778\setup.exe'
          }
          DataServices  = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/mis'
            S3File        = 'DS4303P_4-80007397.EXE'
            WorkingDir    = 'D:\Software'             # Download installer here
            ExtractDir    = 'D:\Software\DS4303P_4-80007397'
            SkipIfPresent = 'D:\Software\DS4303P_4-80007397\setup.exe'
          }
        }
        Variables = @{
          InstallDir     = 'D:\BusinessObjects'
          DSCommonDir    = 'D:\DSCommon'
          LinkDir        = 'D:\BusinessObjects\Data Services'
          SysDbName      = 'STGDXB'
          SysDbUser      = 'ipscms'
          AudDbName      = 'STGDXB'
          AudDbUser      = 'ipsaud'
          SiaNameBase    = 'NDLMODDIS40'
          ServiceUser    = 'delius-mis-stag\SVC_DIS_NDL'
          DomainNameFQDN = 'delius-mis-stage.internal'
        }
        Secrets = @{
          ClusterKey = @{
            SecretName = 'delius-mis-stage-sap-dis-config'
            Key        = 'cluster_key'
          }
          IpsProductKey = @{
            SecretName = 'delius-mis-stage-sap-dis-config'
            Key        = 'ips_product_key'
          }
          DataServicesProductKey = @{
            SecretName = 'delius-mis-stage-sap-dis-config'
            Key        = 'data_services_product_key'
          }
          SysDbPassword = @{
            #SecretName = 'delius-mis-stage-oracle-dsd-db-application-passwords'
            SecretName = 'delius-mis-stage-sap-dis-passwords'
            Key        = 'ipscms'
          }
          AudDbPassword = @{
            #SecretName = 'delius-mis-stage-oracle-dsd-db-application-passwords'
            SecretName = 'delius-mis-stage-sap-dis-passwords'
            Key        = 'ipsaud'
          }
          CmsAdminPassword = @{
            SecretName = 'delius-mis-stage-sap-dis-passwords'
            Key        = 'Administrator'
          }
          ServiceUserPassword = @{
            SecretName = 'delius-mis-stage-sap-dis-passwords'
            Key        = 'SVC_DIS_NDL'
          }
          CmsPrimaryHostname = @{
            SecretName = 'delius-mis-stage-sap-dis-config'
            Key        = 'cms_primary_hostname'
          }
        }
      }
      'delius-mis-preprod-dis' = @{
        InstallPackages = @{
          Ips = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/mis'
            S3File        = 'IPS4304P_900-70002778.EXE'
            WorkingDir    = 'D:\Software'             # Download installer here
            ExtractDir    = 'D:\Software\IPS4304P_900-70002778'
            SkipIfPresent = 'D:\Software\IPS4304P_900-70002778\setup.exe'
          }
          DataServices  = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/mis'
            S3File        = 'DS4303P_4-80007397.EXE'
            WorkingDir    = 'D:\Software'             # Download installer here
            ExtractDir    = 'D:\Software\DS4303P_4-80007397'
            SkipIfPresent = 'D:\Software\DS4303P_4-80007397\setup.exe'
          }
        }
        Variables = @{
          InstallDir     = 'D:\BusinessObjects'
          DSCommonDir    = 'D:\DSCommon'
          LinkDir        = 'D:\BusinessObjects\Data Services'
          SysDbName      = 'PREDXB'
          SysDbUser      = 'ipscms'
          AudDbName      = 'PREDXB'
          AudDbUser      = 'ipsaud'
          SiaNameBase    = 'NDLMODDIS50'
          ServiceUser    = 'delius-mis-prep\SVC_DIS_NDL'
          DomainNameFQDN = 'delius-mis-preprod.internal'
        }
        Secrets = @{
          ClusterKey = @{
            SecretName = 'delius-mis-preprod-sap-dis-config'
            Key        = 'cluster_key'
          }
          IpsProductKey = @{
            SecretName = 'delius-mis-preprod-sap-dis-config'
            Key        = 'ips_product_key'
          }
          DataServicesProductKey = @{
            SecretName = 'delius-mis-preprod-sap-dis-config'
            Key        = 'data_services_product_key'
          }
          SysDbPassword = @{
            SecretName = 'delius-mis-preprod-oracle-dsd-db-application-passwords'
            Key        = 'ipscms'
          }
          AudDbPassword = @{
            SecretName = 'delius-mis-preprod-oracle-dsd-db-application-passwords'
            Key        = 'ipsaud'
          }
          CmsAdminPassword = @{
            SecretName = 'delius-mis-preprod-sap-dis-passwords'
            Key        = 'Administrator'
          }
          ServiceUserPassword = @{
            SecretName = 'delius-mis-preprod-sap-dis-passwords'
            Key        = 'SVC_DIS_NDL'
          }
          CmsPrimaryHostname = @{
            SecretName = 'delius-mis-preprod-sap-dis-config'
            Key        = 'cms_primary_hostname'
          }
        }
      }
    }
    'delius-mis-production' = @{
      'delius-mis-prod-dis' = @{
        InstallPackages = @{
          Ips = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/mis'
            S3File        = 'IPS4304P_900-70002778.EXE'
            WorkingDir    = 'D:\Software'             # Download installer here
            ExtractDir    = 'D:\Software\IPS4304P_900-70002778'
            SkipIfPresent = 'D:\Software\IPS4304P_900-70002778\setup.exe'
          }
          DataServices  = @{
            S3BucketName  = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path        = 'hmpps/mis'
            S3File        = 'DS4303P_4-80007397.EXE'
            WorkingDir    = 'D:\Software'             # Download installer here
            ExtractDir    = 'D:\Software\DS4303P_4-80007397'
            SkipIfPresent = 'D:\Software\DS4303P_4-80007397\setup.exe'
          }
        }
        Variables = @{
          InstallDir     = 'D:\BusinessObjects'
          DSCommonDir    = 'D:\DSCommon'
          LinkDir        = 'D:\BusinessObjects\Data Services'
          SysDbName      = 'PRDDXB'
          SysDbUser      = 'ipscms'
          AudDbName      = 'PRDDXB'
          AudDbUser      = 'ipsaud'
          SiaNameBase    = 'NDLMODDIS00'
          ServiceUser    = 'delius-mis-prod\SVC_DIS_NDL'
          DomainNameFQDN = 'delius-mis-prod.internal'
        }
        Secrets = @{
          ClusterKey = @{
            SecretName = 'delius-mis-prod-sap-dis-config'
            Key        = 'cluster_key'
          }
          IpsProductKey = @{
            SecretName = 'delius-mis-prod-sap-dis-config'
            Key        = 'ips_product_key'
          }
          DataServicesProductKey = @{
            SecretName = 'delius-mis-prod-sap-dis-config'
            Key        = 'data_services_product_key'
          }
          SysDbPassword = @{
            SecretName = 'delius-mis-prod-oracle-dsd-db-application-passwords'
            Key        = 'ipscms'
          }
          AudDbPassword = @{
            SecretName = 'delius-mis-prod-oracle-dsd-db-application-passwords'
            Key        = 'ipsaud'
          }
          CmsAdminPassword = @{
            SecretName = 'delius-mis-prod-sap-dis-passwords'
            Key        = 'Administrator'
          }
          ServiceUserPassword = @{
            SecretName = 'delius-mis-prod-sap-dis-passwords'
            Key        = 'SVC_DIS_NDL'
          }
          CmsPrimaryHostname = @{
            SecretName = 'delius-mis-prod-sap-dis-config'
            Key        = 'cms_primary_hostname'
          }
        }
      }
    }
  }

  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $NameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "Name"}).Value
  $EnvironmentNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "environment-name"}).Value

  if ($EnvironmentNameTag -and $NameTag) {
    if ($ModPlatformSAPConfigsByEnvironment.ContainsKey($EnvironmentNameTag)) {
      $ConfigsByName = $ModPlatformSAPConfigsByEnvironment[$EnvironmentNameTag]
      foreach ($Config in $ConfigsByName.GetEnumerator()) {
        if ($NameTag.StartsWith($Config.Name)) {
          $ConfigCopy = $Config.Value.Clone()
          $ConfigCopy.Variables["NameTag"]            = $NameTag
          $ConfigCopy.Variables["EnvironmentNameTag"] = $EnvironmentNameTag
          $ConfigCopy.Variables["NameTagIndex"]       = $NameTag.split("-")[-1]
          $ConfigCopy.Variables["NameTagNoDashes"]    = $NameTag.replace("-","")
          return $ConfigCopy
        }
      }
      Write-Error "No matching configuration for ${NameTag} in environment-name ${EnvironmentNameTag}"
    } else {
      Write-Error "No matching configuration for environment-name ${EnvironmentNameTag}"
    }
  } else {
    Write-Error "Cannot find SAP configuration, ensure environment-name and Name tag defined"
  }
}

function Get-ModPlatformSAPSecret {
<#
.SYNOPSIS
    Helper function for retrieving passwords from SecretsManager Secrets
#>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][hashtable]$Secrets,
    [Parameter(Mandatory=$true)][string]$SecretName,
    [Parameter(Mandatory=$true)][string]$SecretKey
  )

  if ($Secrets.ContainsKey($SecretName)) {
    $SecretValueRaw = $Secrets[$SecretName]
  } else {
    $SecretValueRaw = aws secretsmanager get-secret-value --secret-id "${SecretName}" --query SecretString --output text
    $Secrets[$SecretName] = $SecretValueRaw
  }
  $SecretJson = "$SecretValueRaw" | ConvertFrom-Json
  $SecretJson.$SecretKey
}

function Get-ModPlatformSAPSecrets {
<#
.SYNOPSIS
    Retrieve secrets from SecretsManager Secrets and return in hashtable

.PARAMETER ModPlatformSAPConfigs
    Output of Get-ModPlatformSAPConfig
#>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][hashtable]$ModPlatformSAPConfig
  )

  $SAPConfigSecrets = @{}
  $SecretValues = @{}
  foreach ($Secret in $ModPlatformSAPConfig.Secrets.GetEnumerator()) {
    $SecretValue = Get-ModPlatformSAPSecret $SAPConfigSecrets $Secret.Value.SecretName $Secret.Value.Key
    if (-not $SecretValue) {
      Write-Error ("Missing key '" + $Secret.Value.Key + "' in secret " + $Secret.Value.SecretName)
    }
    $SecretValues[$Secret.Name] = $SecretValue
  }
  return $SecretValues
}

Export-ModuleMember -Function Get-ModPlatformSAPConfig
Export-ModuleMember -Function Get-ModPlatformSAPSecrets
