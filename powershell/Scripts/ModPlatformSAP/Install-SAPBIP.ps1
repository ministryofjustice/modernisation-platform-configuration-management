Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Get-SAPInstaller $SAPConfig.InstallPackages.Bip
Expand-SAPInstaller $SAPConfig.InstallPackages.Bip
#Add-SAPDirectories $SAPConfig.Variables
#Copy-SAPResponseFile "../../" "response-install-ips.ini" $SAPConfig.InstallPackages.Ips $SAPConfig.Variables $SAPSecrets
