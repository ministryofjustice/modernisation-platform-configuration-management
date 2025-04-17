<#
.SYNOPSIS
    Configure Dns Zone Search List

.DESCRIPTION
    Set the DNS client's SuffixSearchList.

    All possible SuffixSearchLists must be defined in the
    below $Configs variable. This is a hashtable where the
    key is the ConfigName and the value is the list of domains.

.PARAMETER ConfigName
    Optionally provide the name of the config to apply instead
    of deriving from the EC2's environment-name tag value.

.EXAMPLE
    Add-DnsSuffixSearchList.ps1
    Add-DnsSuffixSearchList.ps1 -ConfigName hmpps-domain-services-test
#>

[CmdletBinding()]
param (
  [string]$ConfigName
)

$Configs = @{
  "hmpps-domain-services-development" = @(
    "us-east-1.ec2-utilities.amazonaws.com",
    "eu-west-2.compute.internal",
    "eu-west-2.ec2-utilities.amazonaws.com",
    "azure.noms.root",
    "hmpps-oem.hmpps-development.modernisation-platform.internal",
    "nomis.hmpps-development.modernisation-platform.internal"
  )
  "hmpps-domain-services-test" = @(
    "us-east-1.ec2-utilities.amazonaws.com",
    "eu-west-2.compute.internal",
    "eu-west-2.ec2-utilities.amazonaws.com",
    "azure.noms.root",
    "hmpps-oem.hmpps-test.modernisation-platform.internal",
    "nomis.hmpps-test.modernisation-platform.internal",
    "nomis-combined-reporting.hmpps-test.modernisation-platform.internal",
    "nomis-data-hub.hmpps-test.modernisation-platform.internal",
    "oasys.hmpps-test.modernisation-platform.internal",
    "oasys-national-reporting.hmpps-test.modernisation-platform.internal"
  )
  "hmpps-domain-services-preproduction" = @(
    "us-east-1.ec2-utilities.amazonaws.com",
    "eu-west-2.compute.internal",
    "eu-west-2.ec2-utilities.amazonaws.com",
    "azure.hmpp.root",
    "hmpps-oem.hmpps-preproduction.modernisation-platform.internal",
    "nomis.hmpps-preproduction.modernisation-platform.internal",
    "nomis-combined-reporting.hmpps-preproduction.modernisation-platform.internal",
    "nomis-data-hub.hmpps-preproduction.modernisation-platform.internal",
    "oasys.hmpps-preproduction.modernisation-platform.internal",
    "oasys-national-reporting.hmpps-preproduction.modernisation-platform.internal"
  )
  "hmpps-domain-services-production" = @(
    "us-east-1.ec2-utilities.amazonaws.com",
    "eu-west-2.compute.internal",
    "eu-west-2.ec2-utilities.amazonaws.com",
    "azure.hmpp.root",
    "hmpps-oem.hmpps-production.modernisation-platform.internal",
    "nomis.hmpps-production.modernisation-platform.internal",
    "nomis-combined-reporting.hmpps-production.modernisation-platform.internal",
    "nomis-data-hub.hmpps-production.modernisation-platform.internal",
    "oasys.hmpps-production.modernisation-platform.internal",
    "oasys-national-reporting.hmpps-production.modernisation-platform.internal"
  )
  "nomis-development" = @(
    "us-east-1.ec2-utilities.amazonaws.com",
    "eu-west-2.compute.internal",
    "eu-west-2.ec2-utilities.amazonaws.com",
    "azure.noms.root",
    "nomis.hmpps-development.modernisation-platform.internal"
  )
  "nomis-test" = @(
    "us-east-1.ec2-utilities.amazonaws.com",
    "eu-west-2.compute.internal",
    "eu-west-2.ec2-utilities.amazonaws.com",
    "azure.noms.root",
    "nomis.hmpps-test.modernisation-platform.internal"
  )
  "nomis-preproduction" = @(
    "us-east-1.ec2-utilities.amazonaws.com",
    "eu-west-2.compute.internal",
    "eu-west-2.ec2-utilities.amazonaws.com",
    "azure.hmpp.root",
    "nomis.hmpps-preproduction.modernisation-platform.internal"
  )
  "nomis-production" = @(
    "us-east-1.ec2-utilities.amazonaws.com",
    "eu-west-2.compute.internal",
    "eu-west-2.ec2-utilities.amazonaws.com",
    "azure.hmpp.root",
    "nomis.hmpps-production.modernisation-platform.internal"
  )
}

function Get-ConfigNameByEnvironmentNameTag {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $EnvironmentNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "environment-name"}).Value

  if ($Configs.Contains($EnvironmentNameTag)) {
    Return $EnvironmentNameTag
  } else {
    Write-Error "Unsupported environment-name tag value $EnvironmentNameTag"
    Return $null
  }
}

$ErrorActionPreference = "Stop"

if (-not $ConfigName) {
  $ConfigName = Get-ConfigNameByEnvironmentNameTag
}
if (-not $Configs.Contains($ConfigName)) {
  Write-Error "Unsupported ConfigName $ConfigName"
}
$TargetSuffixSearchList = $Configs[$ConfigName]
$ExistingSuffixSearchList = (Get-DnsClientGlobalSetting).SuffixSearchList

$Missing = $TargetSuffixSearchList | Where {$ExistingSuffixSearchList -NotContains $_}
$Surplus = $ExistingSuffixSearchList | Where {$TargetSuffixSearchList -NotContains $_}
if ($Missing -or $Surplus) {
  if ($Missing) {
    Write-Output "Updating DNS SuffixSearchList - adding $Missing"
  }
  if ($Surplus) {
    Write-Output "Updating DNS SuffixSearchList - removing $Surplus"
  }
  Set-DnsClientGlobalSetting -SuffixSearchList $TargetSuffixSearchList | Out-Null
}
