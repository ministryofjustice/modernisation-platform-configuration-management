Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Install-SAPDataServices "response-install-ds.ini" $SAPConfig.InstallPackages.DataServices $SAPSecrets
Set-SAPDataServicesServiceControl
