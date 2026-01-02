Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Get-SAPInstaller $SAPConfig.InstallPackages.DataServices
Open-SAPInstaller $SAPConfig.InstallPackages.DataServices
Copy-SAPResponseFile "../../" "response-install-ds.ini" $SAPConfig.InstallPackages.DataServices $SAPConfig.Variables $SAPSecrets
