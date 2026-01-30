Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

. ../Common/Install-7Zip.ps1
$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Get-SAPInstaller $SAPConfig.InstallPackages.FlexiLogReader
Expand-SAPInstaller $SAPConfig.InstallPackages.FlexiLogReader

# Create a shortcut
$ShortcutDir = Join-Path -Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) -ChildPath "4.3 Client Tools"
if (-not (Test-Path $ShortcutDir)) {
  Write-Output "Creating $ShortcutDir"
  New-Item -ItemType Directory -Path $ShortcutDir -Force
}
$TargetPath = Join-Path -Path $SAPConfig.InstallPackages.FlexiLogReader.ExtractDir -ChildPath "FlexiLogReader64"
$TargetPath = Join-Path -Path $TargetPath -ChildPath "FlexiLogReader64.exe"
$ShortcutPath = Join-Path -Path $ShortcutDir -ChildPath "FlexiLogReader64.lnk"
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
$Shortcut.TargetPath = $TargetPath
$Shortcut.IconLocation = $TargetPath
$Shortcut.Save()
