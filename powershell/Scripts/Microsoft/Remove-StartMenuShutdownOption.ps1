<#
.SYNOPSIS
    Hide restart and shutdown options from Start Menu

.DESCRIPTION
    Hide restart and shutdown options from Start Menu to
    prevent accidents

.EXAMPLE
    Remove-StartMenuShutdownOption.ps1
#>

$RegPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\"
if (Test-Path -Path $RegPath) {
  $ItemProperty = Get-ItemProperty -Path $RegPath -Name HideRestart -ErrorAction SilentlyContinue
  if ($ItemProperty -eq $null -or $ItemProperty.HideRestart -ne 1) {
    Write-Output "Setting $RegPath\HideRestart = 1"
    New-ItemProperty -Path $RegPath -Name HideRestart -Value 1 -PropertyType DWORD -Force | Out-Null
  }
  if ($ItemProperty -eq $null -or $ItemProperty.HideShutDown -ne 1) {
    Write-Output "Setting $RegPath\HideShutDown = 1"
    New-ItemProperty -Path $RegPath -Name HideShutDown -Value 1 -PropertyType DWORD -Force | Out-Null
  }
}
