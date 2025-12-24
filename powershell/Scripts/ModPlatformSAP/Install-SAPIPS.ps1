Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Get-SAPInstaller $SAPConfig.InstallPackages.Ips
#Open-SAPInstaller $SAPConfig.InstallPackages.Ips
Set-SAPEnvironmentVars $SAPConfig.Variables
Copy-SAPResponseFile "../../" "response-install-ips.ini" $SAPConfig.InstallPackages.Ips $SAPConfig.Variables $SAPSecrets
Install-SAPIPS "response-install-ips.ini" $SAPConfig.InstallPackages.Ips $SAPSecrets
