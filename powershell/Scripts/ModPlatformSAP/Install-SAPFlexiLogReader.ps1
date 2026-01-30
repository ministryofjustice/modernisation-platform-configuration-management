Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

. ../Common/Install-7Zip.ps1
$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
Get-SAPInstaller $SAPConfig.InstallPackages.FlexiLogReader
Open-SAPInstaller $SAPConfig.InstallPackages.FlexiLogReader
