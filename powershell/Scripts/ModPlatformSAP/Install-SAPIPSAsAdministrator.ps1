Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Install-SAPIPS "response-install-ips.ini" $SAPConfig.InstallPackages.Ips $SAPSecrets
Set-SAPIPSServiceControl $SAPConfig.Variables $SAPSecrets
