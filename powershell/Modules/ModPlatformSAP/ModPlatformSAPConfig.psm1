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
        sysDb = @{
          Name = 'T2BOSYS'
          User = 'bods_ips_system_owner'
          SecretName = '/oracle/database/T2BOSYS/passwords'
        }
        audDb = @{
          Name = 'T2BOAUD'
          User = 'bods_ips_audit_owner'
          SecretName = '/oracle/database/T2BOAUD/passwords'
        }
      }
    }
    'oasys-national-reporting-preproduction' = @{
      'pp-onr-bods' = @{
        sysDb = @{
          Name = 'PPBOSYS'
          User = 'bods_ips_system_owner'
          SecretName = '/oracle/database/PPBOSYS/passwords'
        }
        audDb = @{
          Name = 'PPBOAUD'
          User = 'bods_ips_audit_owner'
          SecretName = '/oracle/database/PPBOAUD/passwords'
        }
      }
    }
    'oasys-national-reporting-production' = @{
      'pd-onr-bods' = @{
        sysDb = @{
          Name = 'PDBOSYS'
          User = 'bods_ips_system_owner'
          SecretName = '/oracle/database/PDBOSYS/passwords'
        }
        audDb = @{
          Name = 'PDBOAUD'
          User = 'bods_ips_audit_owner'
          SecretName = '/oracle/database/PDBOAUD/passwords'
        }
      }
    }
    'delius-mis-development' = @{
      'delius-mis-dev-dfi' = @{
        sysDb = @{
          Name = 'DMDDSD'
          User = 'dfi_mod_ipscms'
          SecretName = 'delius-mis-dev-oracle-dsd-db-application-passwords'
        }
        audDb = @{
          Name = 'DMDDSD'
          User = 'dfi_mod_ipsaud'
          SecretName = 'delius-mis-dev-oracle-dsd-db-application-passwords'
        }
      }
      'delius-mis-dev-dis' = @{
        sysDb = @{
          Name = 'DMDDXB'
          User = 'ipscms'
          SecretName = 'delius-mis-dev-oracle-dsd-db-application-passwords'
        }
        audDb = @{
          Name = 'DMDDXB'
          User = 'ipsaud'
          SecretName = 'delius-mis-dev-oracle-dsd-db-application-passwords'
        }
      }
    }
    'delius-mis-preproduction' = @{
      'delius-mis-stage-dis' = @{
        sysDb = @{
          Name = 'STGDXB'
          User = 'ipscms'
          #SecretName = 'delius-mis-stage-oracle-dsd-db-application-passwords'
          SecretName = 'delius-mis-stage-sap-dis-passwords'
        }
        audDb = @{
          Name = 'STGDXB'
          User = 'ipsaud'
          #SecretName = 'delius-mis-stage-oracle-dsd-db-application-passwords'
          SecretName = 'delius-mis-stage-sap-dis-passwords'
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
    [Parameter(Mandatory=$true)][hashtable]$Object,
    [Parameter(Mandatory=$true)][string]$SecretKey,
    [Parameter(Mandatory=$true)][string]$UserKey,
    [Parameter(Mandatory=$true)][string]$PasswordKey
  )

  $SecretName = $Object.$SecretKey
  if ($Secrets.ContainsKey($SecretName)) {
    $SecretValueRaw = $Secrets[$SecretName]
  } else {
    $SecretValueRaw = aws secretsmanager get-secret-value --secret-id "${SecretName}" --query SecretString --output text
    $Secrets[$SecretName] = $SecretValueRaw
  }
  $Username = $Object.$UserKey
  $Password = $null
  $SecretJson = "$SecretValueRaw" | ConvertFrom-Json
  $Password = $SecretJson.$Username
  if ($Password) {
    $Object[$PasswordKey] = ConvertTo-SecureString $Password -AsPlainText -Force
  }
}

function Get-ModPlatformSAPCredentials {
<#
.SYNOPSIS
    Retrieve passwords from SecretsManager Secretsi and append to config object

.PARAMETER ModPlatformSAPConfigs
    Output of Get-ModPlatformSAPConfig
#>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][hashtable]$ModPlatformSAPConfig
  )



  $SAPConfigSecrets = @{}
  Get-ModPlatformSAPSecret $SAPConfigSecrets $ModPlatformSAPConfig.SysDb SecretName User Password
  Get-ModPlatformSAPSecret $SAPConfigSecrets $ModPlatformSAPConfig.AudDb SecretName User Password
}

Export-ModuleMember -Function Get-ModPlatformSAPConfig
Export-ModuleMember -Function Get-ModPlatformSAPCredentials
