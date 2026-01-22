Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Get-SAPInstaller $SAPConfig.InstallPackages.Client
Open-SAPInstaller $SAPConfig.InstallPackages.Client
Copy-SAPResponseFile "../../" "response-install-client.ini" $SAPConfig.InstallPackages.Client $SAPConfig.Variables $SAPSecrets
