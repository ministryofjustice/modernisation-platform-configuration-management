function Get-ModPlatformADConfig {

<#
.SYNOPSIS
    Retrieve appropriate AD config for the given Modernisation Platform environment.

.DESCRIPTION
    Either pass in the domain name as a parameter, or derive the AD configuration
    from EC2 tags (environment-name or domain-name).
    EC2 requires permissions to get tags and the aws cli.

.PARAMETER DomainNameFQDN
    Optionally specify the FQDN of the domain name to join

.EXAMPLE
    $ADConfig = Get-ModPlatformADConfig

.OUTPUTS
    HashTable
#>

  [CmdletBinding()]
  param (
    [string]$DomainNameFQDN
  )

  $ErrorActionPreference = "Stop"

  $ModPlatformADConfigs = @{
    "azure.noms.root" = @{
      "EnvironmentNameTags" = @(
        "hmpps-domain-services-development",
        "hmpps-domain-services-test",
        "planetfm-development",
        "planetfm-test",
        "corporate-staff-rostering-development",
        "corporate-staff-rostering-test"
      )
      "SecretAccountName" = "hmpps-domain-services-test"
      "SecretName" = "/microsoft/AD/azure.noms.root/shared-passwords"
      "DomainNameFQDN" = "azure.noms.root"
      "DomainNameNetbios" = "AZURE"
      "DomainJoinUsername" = "svc_join_domain"
    }
    "azure.hmpp.root" = @{
      "EnvironmentNameTags" = @(
        "hmpps-domain-services-preproduction",
        "hmpps-domain-services-production",
        "planetfm-preproduction",
        "planetfm-production",
        "corporate-staff-rostering-preproduction",
        "corporate-staff-rostering-production"
      )
      "SecretAccountName" = "hmpps-domain-services-production"
      "SecretName" = "/microsoft/AD/azure.hmpp.root/shared-passwords"
      "DomainNameFQDN" = "azure.hmpp.root"
      "DomainNameNetbios" = "HMPP"
      "DomainJoinUsername" = "svc_join_domain"
    }
  }

  $ModPlatformADSecretRoleName = @{
    "EC2HmppsDomainSecretsRole" = @{
      "EnvironmentNameTags" = @(
        "hmpps-domain-services-development",
        "hmpps-domain-services-test",
        "hmpps-domain-services-preproduction",
        "hmpps-domain-services-production",
        "planetfm-development",
        "planetfm-test",
        "planetfm-preproduction",
        "planetfm-production",
        "corporate-staff-rostering-development",
        "corporate-staff-rostering-test"
        "corporate-staff-rostering-preproduction",
        "corporate-staff-rostering-production"
      )
    }
  }

  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $DomainNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "domain-name"}).Value
  $EnvironmentNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "environment-name"}).Value

  $Key = $null
  if ($DomainNameFQDN) {
    $Key = $DomainNameFQDN
  } elseif ($DomainNameTag) {
    $Key = $DomainNameTag
  } else {
    foreach ($Config in $ModPlatformADConfigs.GetEnumerator() ) {
      if ($Config.Value["EnvironmentNameTags"].Contains($EnvironmentNameTag)) {
        $Key = $Config.Key
        break
      }
    }
  }
  if ($Key) {
    if ($ModPlatformADConfigs.ContainsKey($Key)) {
      $ConfigCopy = $ModPlatformADConfigs[$Key].Clone()
      foreach ($Config in $ModPlatformADSecretRoleName.GetEnumerator() ) {
        if ($Config.Value["EnvironmentNameTags"].Contains($EnvironmentNameTag)) {
          $ConfigCopy["SecretRoleName"] = $Config.Key
          break
        }
      }
      Return $ConfigCopy
    } else {
      Write-Error "No matching configuration for domain ${Key}"
    }
  }
  else {
    Write-Error "No matching configuration for environment-name ${EnvironmentNameTag}"
  }
}

Export-ModuleMember -Function Get-ModPlatformADConfig
