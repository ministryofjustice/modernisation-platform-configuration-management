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

  $ModPlatformADConfigsByDomainName = @{
    "azure.noms.root" = @{
      "AccountIdsSSMParameterName" = "account_ids"
      "SecretAccountName" = "hmpps-domain-services-test"
      "SecretName" = "/microsoft/AD/azure.noms.root/shared-passwords"
      "SecretRoleName" = "EC2HmppsDomainSecretsRole"
      "DomainNameFQDN" = "azure.noms.root"
      "DomainNameNetbios" = "AZURE"
      "DomainJoinUsername" = "svc_join_domain"
    }
    "azure.hmpp.root" = @{
      "AccountIdsSSMParameterName" = "account_ids"
      "SecretAccountName" = "hmpps-domain-services-production"
      "SecretName" = "/microsoft/AD/azure.hmpp.root/shared-passwords"
      "SecretRoleName" = "EC2HmppsDomainSecretsRole"
      "DomainNameFQDN" = "azure.hmpp.root"
      "DomainNameNetbios" = "HMPP"
      "DomainJoinUsername" = "svc_join_domain"
    }
  }

  $ModPlatformADConfigsByEnvironmentName = @{
    "hmpps-domain-services-development" = @{"DomainName" = "azure.noms.root" }
    "hmpps-domain-services-test" = @{"DomainName" = "azure.noms.root" }
    "hmpps-domain-services-preproduction" = @{"DomainName" = "azure.hmpp.root" }
    "hmpps-domain-services-production" = @{"DomainName" = "azure.hmpp.root" }
    "planetfm-development" = @{"DomainName" = "azure.noms.root" }
    "planetfm-test" = @{"DomainName" = "azure.noms.root" }
    "planetfm-preproduction" = @{"DomainName" = "azure.hmpp.root" }
    "planetfm-production" = @{"DomainName" = "azure.hmpp.root" }
    "corporate-staff-rostering-development" = @{"DomainName" = "azure.noms.root" }
    "corporate-staff-rostering-test" = @{"DomainName" = "azure.noms.root" }
    "corporate-staff-rostering-preproduction" = @{"DomainName" = "azure.hmpp.root" }
    "corporate-staff-rostering-production" = @{"DomainName" = "azure.hmpp.root" }
    "core-shared-services-production" = @{
      "AccountIdsSSMParameterName" = "/ad-fixngo/account_ids"
      "SecretRoleName" = $null
    }
  }

  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $DomainNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "domain-name"}).Value
  $EnvironmentNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "environment-name"}).Value

  $ModPlatformADConfigsByEnvironment = $null
  if ($ModPlatformADConfigsByEnvironmentName.Contains($EnvironmentNameTag)) {
    $ModPlatformADConfigsByEnvironment = $ModPlatformADConfigsByEnvironmentName[$EnvironmentNameTag]
  }

  $Key = $null
  if ($DomainNameFQDN) {
    $Key = $DomainNameFQDN
  } elseif ($DomainNameTag) {
    $Key = $DomainNameTag
  } elseif ($ModPlatformADConfigsByEnvironment) {
    if ($ModPlatformADConfigsByEnvironment.Contains("DomainName")) {
      $Key = $ModPlatformADConfigsByEnvironment.DomainName
    }
  }
  if ($Key) {
    if ($ModPlatformADConfigsByDomainName.ContainsKey($Key)) {
      $ConfigCopy = $ModPlatformADConfigsByDomainName[$Key].Clone()
      if ($ModPlatformADConfigsByEnvironment) {
        ForEach ($ConfigKey in $ModPlatformADConfigsByEnvironment.Keys) {
          $ConfigCopy[$ConfigKey] = $ModPlatformADConfigsByEnvironment[$ConfigKey]
        }
      }
      Return $ConfigCopy
    } else {
      Write-Error "No matching configuration for domain ${Key}"
    }
  } else {
    Write-Error "Cannot find domain configuration, ensure environment-name or domain-name tag defined"
  }
}

Export-ModuleMember -Function Get-ModPlatformADConfig
