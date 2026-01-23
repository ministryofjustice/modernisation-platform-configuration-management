Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Set-SAPEnvironmentVars $SAPConfig.Variables
Install-SAPClient "response-install-client.ini" $SAPConfig.InstallPackages.Client
