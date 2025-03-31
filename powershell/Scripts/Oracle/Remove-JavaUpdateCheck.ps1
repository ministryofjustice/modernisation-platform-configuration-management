<#
.SYNOPSIS
    Disable Automated Java Update Checks

.EXAMPLE
    Remove-JavaUpdateCheck.ps1
#>

$RegPath = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"
$ItemName = "SunJavaUpdateSched"
$ItemProperty = Get-ItemProperty -Path $RegPath -Name $ItemName -ErrorAction SilentlyContinue
if ($ItemProperty -ne $null) {
  Write-Output "Removing $ItemName from $RegPath"
  Remove-ItemProperty -Path $RegPath -Name $ItemName -Force
}

$RegPath = "HKLM:\SOFTWARE\Wow6432Node\JavaSoft\Java Update\Policy"
if (!(Test-Path $RegPath)) {
  Write-Output "Creating $RegPath"
  New-Item -Path $RegPath -Force | Out-Null
}

$ItemName = "EnableJavaUpdate"
$ItemProperty = Get-ItemProperty -Path $RegPath -Name $ItemName -ErrorAction SilentlyContinue
if ($ItemProperty -eq $null -or $ItemProperty.$ItemName -ne 0) {
  Write-Output "Setting $RegPath\$ItemName = 0"
  New-ItemProperty -Path $RegPath -Name $ItemName -Value 0 -PropertyType DWORD -Force | Out-Null
}
