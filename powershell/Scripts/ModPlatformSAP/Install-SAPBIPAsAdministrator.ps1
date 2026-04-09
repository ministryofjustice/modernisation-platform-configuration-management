Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
Install-SAPBPS "response-install-bip.ini" $SAPConfig.InstallPackages.Bip
