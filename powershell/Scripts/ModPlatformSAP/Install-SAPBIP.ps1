Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Get-SAPInstaller $SAPConfig.InstallPackages.Bip
Expand-SAPInstaller $SAPConfig.InstallPackages.Bip
Copy-SAPResponseFile "../../" "response-install-bip.ini" $SAPConfig.InstallPackages.Bip $SAPConfig.Variables $SAPSecrets
