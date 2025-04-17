<#
.SYNOPSIS
    Configure Add-EdgePopupsAllowedForUrls.ps1

.DESCRIPTION
    Configure Edge Urls that allow popups

.EXAMPLE
    Add-EdgePopupsAllowedForUrls.ps1
#>

$PopupsAllowedForUrls = @(
  "[*.]justice.gov.uk",
  "[*.]eu-west-2.compute.internal"
)

$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\PopupsAllowedForUrls"

if (!(Test-Path $RegPath)) {
  Write-Output "Creating $RegPath"
  New-Item -Path $RegPath -Force | Out-Null
}

$ItemName = 1
foreach ($PopupsAllowedForUrl in $PopupsAllowedForUrls) {
  $ItemProperty = Get-ItemProperty -Path $RegPath -Name $ItemName -ErrorAction SilentlyContinue
  if ($null -eq $ItemProperty -or $ItemProperty.$ItemName -ne $PopupsAllowedForUrl) {
    Write-Output "Setting $RegPath\$ItemName = $PopupsAllowedForUrl"
    New-ItemProperty -Path $RegPath -Name $ItemName -Value $PopupsAllowedForUrl -PropertyType String -Force | Out-Null
  }
  $ItemName = $ItemName + 1
}

$ItemProperty = Get-ItemProperty -Path $RegPath -Name $ItemName -ErrorAction SilentlyContinue
while ($null -ne $ItemProperty) {
  $PopupsAllowedForUrl = $ItemProperty.$ItemName
  Write-Output "Removing $RegPath\$ItemName = $PopupsAllowedForUrl"
  Remove-ItemProperty -Path $RegPath -Name $ItemName | Out-Null
  $ItemName = $ItemName + 1
  $ItemProperty = Get-ItemProperty -Path $RegPath -Name $ItemName -ErrorAction SilentlyContinue
}
