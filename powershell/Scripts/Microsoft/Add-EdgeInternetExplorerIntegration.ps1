<#
.SYNOPSIS
    Configure Edge Internet Explorer Compatibility Mode

.DESCRIPTION
    Configure the IE Integration Level to IEMode
    Configure the IE Compatibility Mode Site List
    Configure the IE Trusted Domains

    All environment specific configurations must be defined in the
    below $Configs variable. This is a hashtable where the
    key is the ConfigName and the value is a hashtable of options:
    - CompatibilityModeSiteListFilePath: location of site list
    - CompatibilityModeSiteList:         list of IE mode URLs
    - TrustedDomains:                    list of trusted domains

.PARAMETER ConfigName
    Optionally provide the name of the config to apply instead
    of deriving from the EC2's environment-name tag value.

.EXAMPLE
    Add-EdgeInternetExplorerIntegration.ps1
    Add-EdgeInternetExplorerIntegration.ps1 -ConfigName hmpps-domain-services-test
#>

[CmdletBinding()]
param (
  [string]$ConfigName
)

$Configs = @{
  "hmpps-domain-services-development" = @{
    "CompatibilityModeSiteListFilePath" = "C:\IECompatibilitySiteList.xml"
    "CompatibilityModeSiteList" = @(
      "c-dev.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c-qa11g.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c-qa11r.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "qa11g-nomis-web12-a.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    )
    "TrustedDomains" = @(
      "*.development.nomis.service.justice.gov.uk",
      "*.eu-west-2.compute.internal"
    )
  }
  "hmpps-domain-services-test" = @{
    "CompatibilityModeSiteListFilePath" = "C:\IECompatibilitySiteList.xml"
    "CompatibilityModeSiteList" = @(
      "c-t1.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c-t2.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c-t3.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t1-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t1-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t2-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t2-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t3-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t3-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    )
    "TrustedDomains" = @(
      "*.test.nomis.service.justice.gov.uk",
      "*.eu-west-2.compute.internal"
    )
  }
  "hmpps-domain-services-preproduction" = @{
    "CompatibilityModeSiteListFilePath" = "C:\IECompatibilitySiteList.xml"
    "CompatibilityModeSiteList" = @(
      "c-lsast.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "lsast-nomis-web-a.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "lsast-nomis-web-b.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "preprod-nomis-web-a.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "preprod-nomis-web-b.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    )
    "TrustedDomains" = @(
      "*.preproduction.nomis.service.justice.gov.uk",
      "*.eu-west-2.compute.internal"
    )
  }
  "hmpps-domain-services-production" = @{
    "CompatibilityModeSiteListFilePath" = "C:\IECompatibilitySiteList.xml"
    "CompatibilityModeSiteList" = @(
      "c.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c.nomis.az.justice.gov.uk/forms/frmservlet?config=tag",
      "c.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "prod-nomis-web-a.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "prod-nomis-web-b.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    )
    "TrustedDomains" = @(
      "*.nomis.az.justice.gov.uk",
      "*.nomis.service.justice.gov.uk",
      "*.eu-west-2.compute.internal"
    )
  }
  "nomis-development" = @{
    "CompatibilityModeSiteListFilePath" = "C:\IECompatibilitySiteList.xml"
    "CompatibilityModeSiteList" = @(
      "c-dev.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c-qa11g.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c-qa11r.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "qa11g-nomis-web12-a.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    )
    "TrustedDomains" = @(
      "*.development.nomis.service.justice.gov.uk",
      "*.eu-west-2.compute.internal"
    )
  }
  "nomis-test" = @{
    "CompatibilityModeSiteListFilePath" = "C:\IECompatibilitySiteList.xml"
    "CompatibilityModeSiteList" = @(
      "c-t1.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c-t2.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c-t3.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t1-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t1-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t2-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t2-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t3-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t3-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    )
    "TrustedDomains" = @(
      "*.test.nomis.service.justice.gov.uk",
      "*.eu-west-2.compute.internal"
    )
  }
  "nomis-preproduction" = @{
    "CompatibilityModeSiteListFilePath" = "C:\IECompatibilitySiteList.xml"
    "CompatibilityModeSiteList" = @(
      "c-lsast.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "lsast-nomis-web-a.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "lsast-nomis-web-b.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "preprod-nomis-web-a.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "preprod-nomis-web-b.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    )
    "TrustedDomains" = @(
      "*.preproduction.nomis.service.justice.gov.uk",
      "*.eu-west-2.compute.internal"
    )
  }
  "nomis-production" = @{
    "CompatibilityModeSiteListFilePath" = "C:\IECompatibilitySiteList.xml"
    "CompatibilityModeSiteList" = @(
      "c.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c.nomis.az.justice.gov.uk/forms/frmservlet?config=tag",
      "c.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "prod-nomis-web-a.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "prod-nomis-web-b.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    )
    "TrustedDomains" = @(
      "*.nomis.az.justice.gov.uk",
      "*.nomis.service.justice.gov.uk",
      "*.eu-west-2.compute.internal"
    )
  }
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

function New-CompatibilityModeSiteListXml {
  [CmdletBinding()]
  param (
    [string[]]$CompatibilityModeSiteList
  )
  $XmlDoc = New-Object System.Xml.XmlDocument
  $Root = $XmlDoc.CreateElement("site-list")
  $Root.SetAttribute('version', 1) | Out-Null
  $XmlDoc.AppendChild($Root) | Out-Null
  $CreatedByElement = $XmlDoc.CreateElement("created-by")
  $ToolElement = $XmlDoc.CreateElement("tool")
  $VersionElement = $XmlDoc.CreateElement("version")
  $DateCreatedElement = $XmlDoc.CreateElement("date_created")
  $ToolElement.InnerText = "EMIESiteListManager"
  $VersionElement.InnerText = "1.0.0.0"
  $DateCreatedElement.InnerText = $(Get-Date -Format "MM/dd/yyyy hh:mm:ss")
  $CreatedByElement.AppendChild($ToolElement) | Out-Null
  $CreatedByElement.AppendChild($VersionElement) | Out-Null
  $CreatedByElement.AppendChild($DateCreatedElement) | Out-Null
  $Root.AppendChild($CreatedByElement) | Out-Null

  foreach ($site in $CompatibilityModeSiteList) {
    $SiteElement = $XmlDoc.CreateElement("site")
    $SiteElement.SetAttribute('url', $site) | Out-Null
    $CompatModeElement = $XmlDoc.CreateElement("compat-mode")
    $OpenInElement = $XmlDoc.CreateElement("open-in")
    $OpenInElement.SetAttribute('allow-redirect', 'true')
    $CompatModeElement.InnerText = "Default"
    $OpenInElement.InnerText = "IE11"
    $SiteElement.AppendChild($CompatModeElement) | Out-Null
    $SiteElement.AppendChild($OpenInElement) | Out-Null
    $Root.AppendChild($SiteElement) | Out-Null
  }

  return $XmlDoc
}

$ErrorActionPreference = "Stop"

if (-not $ConfigName) {
  $ConfigName = Get-ConfigNameByEnvironmentNameTag
}
if (-not $Configs.Contains($ConfigName)) {
  Write-Error "Unsupported ConfigName $ConfigName"
}
$Config = $Configs[$ConfigName]
$CompatibilityModeSiteList = $Config.CompatibilityModeSiteList
$TrustedDomains = $Config.TrustedDomains
$CompatibilityModeSiteListFilePath = $Config.CompatibilityModeSiteListFilePath

Write-Output "Creating $CompatibilityModeSiteListFilePath"
$SitesXmlDoc = New-CompatibilityModeSiteListXml -CompatibilityModeSiteList $CompatibilityModeSiteList
$SitesXmlDoc.Save($CompatibilityModeSiteListFilePath) | Out-Null

$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
if (!(Test-Path $RegPath)) {
  Write-Output "Creating $RegPath"
  New-Item -Path $RegPath -Force | Out-Null
}

$ItemProperty = Get-ItemProperty -Path $RegPath -Name InternetExplorerIntegrationLevel -ErrorAction SilentlyContinue
if ($null -eq $ItemProperty -or $ItemProperty.InternetExplorerIntegrationLevel -ne 1) {
  Write-Output "Setting $RegPath\InternetExplorerIntegrationLevel = IEMode"
  New-ItemProperty -Path $RegPath -Name InternetExplorerIntegrationLevel -Value 1 -PropertyType DWORD -Force | Out-Null
}

$ItemProperty = Get-ItemProperty -Path $RegPath -Name InternetExplorerIntegrationSiteList -ErrorAction SilentlyContinue
if ($null -eq $ItemProperty -or $ItemProperty.InternetExplorerIntegrationSiteList -ne $CompatibilityModeSiteListFilePath) {
  Write-Output "Setting $RegPath\InternetExplorerIntegrationSiteList = $CompatibilityModeSiteListFilePath"
  New-ItemProperty -Path $RegPath -Name InternetExplorerIntegrationSiteList -Value $CompatibilityModeSiteListFilePath -PropertyType String -Force | Out-Null
}

if (!(Test-Path $RegPath\EnhanceSecurityModeBypassListDomains)) {
  Write-Output "Creating $RegPath\EnhanceSecurityModeBypassListDomains"
  New-Item -Path $RegPath\EnhanceSecurityModeBypassListDomains -Force | Out-Null
}

$ItemName = 1
foreach ($TrustedDomain in $TrustedDomains) {
  $ItemProperty = Get-ItemProperty -Path "$RegPath\EnhanceSecurityModeBypassListDomains" -Name $ItemName -ErrorAction SilentlyContinue
  if ($null -eq $ItemProperty -or $ItemProperty.$ItemName -ne $TrustedDomain) {
    Write-Output "Setting $RegPath\EnhanceSecurityModeBypassListDomains\$ItemName = $TrustedDomain"
    New-ItemProperty -Path "$RegPath\EnhanceSecurityModeBypassListDomains" -Name $ItemName -Value $TrustedDomain -PropertyType String -Force | Out-Null
  }
  $ItemName = $ItemName + 1
}
$ItemProperty = Get-ItemProperty -Path "$RegPath\EnhanceSecurityModeBypassListDomains" -Name $ItemName -ErrorAction SilentlyContinue
while ($null -ne $ItemProperty) {
  $TrustedDomain = $ItemProperty.$ItemName -replace '^\*\.', ''
  Write-Output "Removing $RegPath\EnhanceSecurityModeBypassListDomains\$ItemName = $TrustedDomain"
  Remove-ItemProperty -Path "$RegPath\EnhanceSecurityModeBypassListDomains" -Name $ItemName | Out-Null
  $ItemName = $ItemName + 1
  $ItemProperty = Get-ItemProperty -Path "$RegPath\EnhanceSecurityModeBypassListDomains" -Name $ItemName -ErrorAction SilentlyContinue
}

$RegPath = "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"
if (!(Test-Path "$RegPath")) {
  Write-Output "Creating $RegPath"
  New-Item -Path "$RegPath" -Force | Out-Null
}

$ItemProperty = Get-ItemProperty -Path "$RegPath" -Name Security_HKLM_only -ErrorAction SilentlyContinue
if ($null -eq $ItemProperty -or $ItemProperty.Security_HKLM_only -ne 1) {
  Write-Output "Setting $RegPath\Security_HKLM_only = 1"
  New-ItemProperty -Path "$RegPath" -Name Security_HKLM_only -Value 1 -PropertyType DWORD -Force | Out-Null
}

$RegPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains"
foreach ($TrustedDomain in $TrustedDomains) {
  if (!(Test-Path "$RegPath\$TrustedDomain")) {
    Write-Output "Creating $RegPath\$TrustedDomain"
    New-Item -Path "$RegPath\$TrustedDomain" -Force | Out-Null
  }
  $ItemProperty = Get-ItemProperty -Path "$RegPath\$TrustedDomain" -Name https -ErrorAction SilentlyContinue
  if ($null -eq $ItemProperty -or $ItemProperty.https -ne 2) {
    Write-Output "Setting $RegPath\$TrustedDomain\https = 2"
    New-ItemProperty -Path "$RegPath\$TrustedDomain" -Name https -Value 2 -PropertyType DWORD -Force | Out-Null
  }
}
