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
    'oasys-national-reporting-test' = @{
      't2-onr-bods' = @{
        Packages = @{
          Ips = @{
            PackagesS3BucketName = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            PackagesPrefix       = 'hmpps/onr'
            PackagesFile         = '51054935.ZIP'            # Information Platform Services 4.2 SP9 Patch 0
            WorkingDirectory     = 'E:\Software'             # Download installer here
          }
          DataServices = @{
            PackagesS3BucketName = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            PackagesPrefix       = 'hmpps/onr'
            PackagesFile         = 'DS4214P_11-20011165.exe' # Data Services 4.2 SP14 Patch 11
            WorkingDirectory     = 'E:\Software'             # Download installer here
          }
        }
        SysDb = @{
          Name = 'T2BOSYS'
          User = 'bods_ips_system_owner'
          SecretName = '/oracle/database/T2BOSYS/passwords'
        }
        AudDb = @{
          Name = 'T2BOAUD'
          User = 'bods_ips_audit_owner'
          SecretName = '/oracle/database/T2BOAUD/passwords'
        }
      }
    }
    'oasys-national-reporting-preproduction' = @{
      'pp-onr-bods' = @{
        SysDb = @{
          Name = 'PPBOSYS'
          User = 'bods_ips_system_owner'
          SecretName = '/oracle/database/PPBOSYS/passwords'
        }
        AudDb = @{
          Name = 'PPBOAUD'
          User = 'bods_ips_audit_owner'
          SecretName = '/oracle/database/PPBOAUD/passwords'
        }
      }
    }
    'oasys-national-reporting-production' = @{
      'pd-onr-bods' = @{
        SysDb = @{
          Name = 'PDBOSYS'
          User = 'bods_ips_system_owner'
          SecretName = '/oracle/database/PDBOSYS/passwords'
        }
        AudDb = @{
          Name = 'PDBOAUD'
          User = 'bods_ips_audit_owner'
          SecretName = '/oracle/database/PDBOAUD/passwords'
        }
      }
    }
    'delius-mis-development' = @{
      'delius-mis-dev-dfi' = @{
        SysDb = @{
          Name = 'DMDDSD'
          User = 'dfi_mod_ipscms'
          SecretName = 'delius-mis-dev-oracle-dsd-db-application-passwords'
        }
        AudDb = @{
          Name = 'DMDDSD'
          User = 'dfi_mod_ipsaud'
          SecretName = 'delius-mis-dev-oracle-dsd-db-application-passwords'
        }
      }
      'delius-mis-dev-dis' = @{
        SysDb = @{
          Name = 'DMDDXB'
          User = 'ipscms'
          SecretName = 'delius-mis-dev-oracle-dsd-db-application-passwords'
        }
        AudDb = @{
          Name = 'DMDDXB'
          User = 'ipsaud'
          SecretName = 'delius-mis-dev-oracle-dsd-db-application-passwords'
        }
      }
    }
    'delius-mis-preproduction' = @{
      'delius-mis-stage-dis' = @{
        InstallPackages = @{
          Ips = @{
            S3BucketName = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path       = 'hmpps/mis'
            S3File       = 'IPS4304P_900-70002778.EXE'
            ExtractDir   = 'IPS4304P_900-70002778'
            WorkingDir   = 'D:\Software'             # Download installer here
          }
          DataServices  = @{
            S3BucketName = 'mod-platform-image-artefact-bucket20230203091453221500000001'
            S3Path       = 'hmpps/mis'
            S3File       = 'DS4303P_4-80007397.EXE'
            ExtractDir   = 'DS4303P_4-80007397'
            WorkingDir   = 'D:\Software'             # Download installer here
          }
        }
        Variables = @{
          InstallDir  = 'D:\BusinessObjects'
          DSCommonDir = 'D:\DSCommon'
          LinkDir     = 'D:\BusinessObjects\Data Services'
          SysDbName   = 'STGDXB'
          SysDbUser   = 'ipscms'
          AudDbName   = 'STGDXB'
          AudDbUser   = 'ipsaud'
          SiaName     = 'NDLMODDIS101'
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
Export-ModuleMember -Function Get-ModPlatformSAPCredentials
