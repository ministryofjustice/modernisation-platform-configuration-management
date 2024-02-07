function Get-ModPlatformADConfig {

<#
.SYNOPSIS
    Retrieve appropriate AD config for the given Modernisation Platform environment.

.DESCRIPTION
    Either pass in the doman name as a parameter, or derive the AD configuration 
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
      "environment-name-tags" = @(
        "hmpps-domain-services-development",
        "hmpps-domain-services-test",
        "planetfm-development",
        "planetfm-test",
        "corporate-staff-rostering-development",
        "corporate-staff-rostering-test"
      )
      "secretAccountName" = "hmpps-domain-services-test"
      "secretName" = "/microsoft/AD/azure.noms.root/shared-passwords"
      "secretRoleName" = "EC2HmppsDomainSecretsRole"
      "domainNameFQDN" = "azure.noms.root"
      "domainNameNetbios" = "AZURE"
      "domainJoinUsername" = "svc_join_domain"
    }
    "azure.hmpp.root" = @{
      "environment-name-tags" = @(
        "hmpps-domain-services-preproduction",
        "hmpps-domain-services-production",
        "planetfm-preproduction",
        "planetfm-production",
        "corporate-staff-rostering-preproduction",
        "corporate-staff-rostering-production"
      ) 
      "secretAccountName" = "hmpps-domain-services-production"
      "secretName" = "/microsoft/AD/azure.hmpp.root/shared-passwords"
      "secretRoleName" = "EC2HmppsDomainSecretsRole"
      "domainNameFQDN" = "azure.hmpp.root"
      "domainNameNetbios" = "HMPP"
      "domainJoinUsername" = "svc_join_domain"
    }
  }

  if ($DomainNameFQDN -ne $null -and $ModPlatformADConfigs.ContainsKey($DomainNameFQDN)) {
    return $ModPlatformADConfigs.[string]$DomainNameFQDN
  }  
  $Token = Invoke-RestMethod -ConnectionTimeoutSeconds 2 -OperationTimeoutSeconds 2 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -ConnectionTimeoutSeconds 2 -OperationTimeoutSeconds 2 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $DomainNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "domain-name"}).Value
  $EnvironmentNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "environment-name"}).Value

  if ($DomainNameTag -ne $null -and $ModPlatformADConfigs.containsKey($DomainNameTag)) {
    return $ModPlatformADConfigs.[string]$DomainNameTag
  }

  foreach ($Config in $ModPlatformADConfigs.GetEnumerator() ) {
    if ($Config.Value["environment-name-tags"].Contains($EnvironmentNameTag)) {
      return $Config
    }
  }

  Write-Error "No matching configuration for environment-name $EnvironmentNameTag"
}

Export-ModuleMember -Function Get-ModPlatformADConfig
