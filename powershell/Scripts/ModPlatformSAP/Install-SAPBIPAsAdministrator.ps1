Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
Install-SAPBIP "response-install-bip.ini" $SAPConfig.InstallPackages.Bip
