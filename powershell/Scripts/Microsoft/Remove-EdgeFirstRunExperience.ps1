<#
.SYNOPSIS
    Hide the Edge first run experience for all users

.EXAMPLE
    Remove-EdgeFirstRunExperience.ps1
#>

$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

if (!(Test-Path $RegPath)) {
  if ($env:DRYRUN -eq "true") {
    Write-Output "DRYRUN: Creating $RegPath"
  } else {
    Write-Output "Creating $RegPath"
    New-Item -Path $RegPath -Force | Out-Null
  }
}

$ItemProperty = Get-ItemProperty -Path $RegPath -Name HideFirstRunExperience -ErrorAction SilentlyContinue

if (($null -eq $ItemProperty) -or ($ItemProperty.HideFirstRunExperience -ne 1)) {
  if ($env:DRYRUN -eq "true") {
    Write-Output "DRYRUN: Setting $RegPath\HideFirstRunExperience = 1"
  } else {
    Write-Output "Setting $RegPath\HideFirstRunExperience = 1"
    New-ItemProperty -Path $RegPath -Name HideFirstRunExperience -Value 1 -PropertyType DWORD -Force | Out-Null
  }
}
