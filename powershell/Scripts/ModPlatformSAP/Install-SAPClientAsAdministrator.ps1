Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Set-SAPEnvironmentVars $SAPConfig.Variables
Install-SAPClient "response-install-client.ini" $SAPConfig.InstallPackages.Client

$ShortcutPath = Join-Path -Path $ShortcutDir -ChildPath "Designer (User Specific).lnk"
if (-not (Test-Path $ShortcutPath)) {
  Write-Output "Creating Desktop Shortcut: $ShortcutPath"
  $WScriptShell = New-Object -ComObject WScript.Shell
  $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
  $TargetPath = Join-Path -Path $SAPConfig.Variables.InstallDir -ChildPath "SAP BusinessObjects Enterprise XI 4.0"
  $TargetPath = Join-Path -Path $TargetPath -ChildPath "win64_x64"
  $TargetPath = Join-Path -Path $TargetPath -ChildPath "designer.exe"
  $Shortcut.TargetPath = $TargetPath
  $Shortcut.Arguments = "-configuration '%USERPROFILE%\Documents'"
  $Shortcut.IconLocation = $TargetPath
  $Shortcut.Save()
} else {
  Write-Output "Skipping Desktop Shortcut as $ShortcutPath already present"
}

$ShortcutPath = Join-Path -Path $ShortcutDir -ChildPath "Information Design Tool (User Specific).lnk"
if (-not (Test-Path $ShortcutPath)) {
  Write-Output "Creating Desktop Shortcut: $ShortcutPath"
  $WScriptShell = New-Object -ComObject WScript.Shell
  $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
  $TargetPath = Join-Path -Path $SAPConfig.Variables.InstallDir -ChildPath "SAP BusinessObjects Enterprise XI 4.0"
  $TargetPath = Join-Path -Path $TargetPath -ChildPath "win64_x64"
  $TargetPath = Join-Path -Path $TargetPath -ChildPath "InformationDesignTool.exe"
  $Shortcut.TargetPath = $TargetPath
  $Shortcut.Arguments = "-configuration '%USERPROFILE%\Documents'"
  $Shortcut.IconLocation = $TargetPath
  $Shortcut.Save()
} else {
  Write-Output "Skipping Desktop Shortcut as $ShortcutPath already present"
}
