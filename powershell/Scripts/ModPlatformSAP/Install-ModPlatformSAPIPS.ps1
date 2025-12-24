Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Get-SAPInstaller $SAPConfig.InstallPackages.Ips
Extract-SAPInstaller $SAPConfig.InstallPackages.Ips

Set-SAPEnvironmentVars $SAPConfig.Variables
Extract-SAPResponseFile "../../../" "response-install-ips.ini" $SAPConfig.InstallPackages.Ips $SAPConfig.Variables $SAPSecrets
