Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Set-SAPEnvironmentVars $SAPConfig.Variables
Install-SAPClient "response-install-client.ini" $SAPConfig.InstallPackages.Client

$ShortcutDir = Join-Path -Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) -ChildPath "4.3 Client Tools"
$ShortcutPath = Join-Path -Path $ShortcutDir -ChildPath "Designer.lnk"
if (-not (Test-Path $ShortcutPath)) {
  Write-Output "Creating Desktop Shortcut: $ShortcutPath"
  $WScriptShell = New-Object -ComObject WScript.Shell
  $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
  $TargetPath = Join-Path -Path $SAPConfig.Variables.InstallDir -ChildPath "SAP BusinessObjects Enterprise XI 4.0"
  $TargetPath = Join-Path -Path $TargetPath -ChildPath "win64_x64"
  $TargetPath = Join-Path -Path $TargetPath -ChildPath "designer.exe"
  $Shortcut.TargetPath = $TargetPath
  # Comment in to use a per-user configuration instead of global
  # $Shortcut.Arguments = "-configuration %USERPROFILE%"
  $Shortcut.IconLocation = $TargetPath
  $Shortcut.Save()
} else {
  Write-Output "Skipping Desktop Shortcut as $ShortcutPath already present"
}

$ShortcutPath = Join-Path -Path $ShortcutDir -ChildPath "Information Design Tool.lnk"
if (-not (Test-Path $ShortcutPath)) {
  Write-Output "Creating Desktop Shortcut: $ShortcutPath"
  $WScriptShell = New-Object -ComObject WScript.Shell
  $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
  $TargetPath = Join-Path -Path $SAPConfig.Variables.InstallDir -ChildPath "SAP BusinessObjects Enterprise XI 4.0"
  $TargetPath = Join-Path -Path $TargetPath -ChildPath "win64_x64"
  $TargetPath = Join-Path -Path $TargetPath -ChildPath "InformationDesignTool.exe"
  $Shortcut.TargetPath = $TargetPath
  # Comment in to use a per-user configuration instead of global
  # $Shortcut.Arguments = "-configuration %USERPROFILE%"
  $Shortcut.IconLocation = $TargetPath
  $Shortcut.Save()
} else {
  Write-Output "Skipping Desktop Shortcut as $ShortcutPath already present"
}
