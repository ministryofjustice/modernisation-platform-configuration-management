<#
.SYNOPSIS
    Hide restart and shutdown options from Start Menu

.DESCRIPTION
    Hide restart and shutdown options from Start Menu to
    prevent accidents

.EXAMPLE
    Remove-StartMenuShutdownOption.ps1
#>

$RegPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start"
if (Test-Path -Path $RegPath) {
  $ItemProperty = Get-ItemProperty -Path "$RegPath\HideRestart" -Name value -ErrorAction SilentlyContinue
  if ($null -eq $ItemProperty -or $ItemProperty.value -ne 1) {
    if ($env:DRYRUN -eq "true") {
      Write-Output "DRYRUN: Setting $RegPath\HideRestart\value = 1"
    } else {
      Write-Output "Setting $RegPath\HideRestart\value = 1"
      New-ItemProperty -Path "$RegPath\HideRestart" -Name value -Value 1 -PropertyType DWORD -Force | Out-Null
    }
  }

  $ItemProperty = Get-ItemProperty -Path "$RegPath\HideShutDown" -Name value -ErrorAction SilentlyContinue
  if ($null -eq $ItemProperty -or $ItemProperty.value -ne 1) {
    if ($env:DRYRUN -eq "true") {
      Write-Output "DRYRUN: Setting $RegPath\HideShutDown\value = 1"
    } else {
      Write-Output "Setting $RegPath\HideShutDown\value = 1"
      New-ItemProperty -Path "$RegPath\HideShutDown" -Name value -Value 1 -PropertyType DWORD -Force | Out-Null
    }
  }
}
