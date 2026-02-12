Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Get-SAPInstaller $SAPConfig.InstallPackages.Ips
Expand-SAPInstaller $SAPConfig.InstallPackages.Ips
Add-SAPDirectories $SAPConfig.Variables
Copy-SAPResponseFile "../../" "response-install-ips.ini" $SAPConfig.InstallPackages.Ips $SAPConfig.Variables $SAPSecrets
