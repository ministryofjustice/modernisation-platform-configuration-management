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
