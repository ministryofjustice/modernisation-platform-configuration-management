Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig = Get-ModPlatformSAPConfig
Get-ModPlatformSAPCredentials $SAPConfig
$SysDbStatus = Test-OracleConnection $SAPConfig.SysDb.Name $SAPConfig.SysDb.User $SAPConfig.SysDb.Password
$AudDbStatus = Test-OracleConnection $SAPConfig.AudDb.Name $SAPConfig.AudDb.User $SAPConfig.AudDb.Password 

if ($SysDbStatus -ne 0 -or $AudDbStatus -ne 0) {
  Write-Error "Error testing connection to sys/aud database"
}
