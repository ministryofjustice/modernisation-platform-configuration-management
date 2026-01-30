Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Get-SAPInstaller $SAPConfig.InstallPackages.Client
Expand-SAPInstaller $SAPConfig.InstallPackages.Client
Copy-SAPResponseFile "../../" "response-install-client.ini" $SAPConfig.InstallPackages.Client $SAPConfig.Variables $SAPSecrets

$ShortcutDir = Join-Path -Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) -ChildPath "4.3 Client Tools"
if (-not (Test-Path $ShortcutDir)) {
  Write-Output "Creating Desktop Folder: $ShortcutDir"
  New-Item -ItemType Directory -Path $ShortcutDir -Force
}

$ShortcutPath = Join-Path -Path $ShortcutDir -ChildPath "Designer.lnk"
if (-not (Test-Path $ShortcutPath)) {
  Write-Output "Creating Desktop Shortcut: $ShortcutDir"
  $WScriptShell = New-Object -ComObject WScript.Shell
  $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
  $TargetPath = Join-Path -Path $SAPConfig.Variables.InstallDir -ChildPath "SAP BusinessObjects Enterprise XI 4.0"
  $TargetPath = Join-Path -Path $TargetPath -ChildPath "win64_x64"
  $TargetPath = Join-Path -Path $TargetPath -ChildPath "designer.exe"
  $Shortcut.TargetPath = $TargetPath
  $Shortcut.IconLocation = $TargetPath
  $Shortcut.Save()
} else {
  Write-Output "Skipping Desktop Shortcut as $ShortcutPath already present"
}

$ShortcutPath = Join-Path -Path $ShortcutDir -ChildPath "Information Design Tool.lnk"
if (-not (Test-Path $ShortcutPath)) {
  Write-Output "Creating Desktop Shortcut: $ShortcutDir"
  $WScriptShell = New-Object -ComObject WScript.Shell
  $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
  $TargetPath = Join-Path -Path $SAPConfig.Variables.InstallDir -ChildPath "SAP BusinessObjects Enterprise XI 4.0"
  $TargetPath = Join-Path -Path $TargetPath -ChildPath "win64_x64"
  $TargetPath = Join-Path -Path $TargetPath -ChildPath "InformationDesignTool.exe"
  $Shortcut.TargetPath = $TargetPath
  $Shortcut.IconLocation = $TargetPath
  $Shortcut.Save()
} else {
  Write-Output "Skipping Desktop Shortcut as $ShortcutPath already present"
}
