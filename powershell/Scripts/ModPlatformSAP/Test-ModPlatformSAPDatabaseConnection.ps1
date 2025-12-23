Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
$SysDbStatus = Test-OracleConnection $SAPConfig.Config.SysDbName $SAPConfig.Config.SysDbUser (ConvertTo-SecureString $SAPSecrets.SysDbPassword -AsPlainText -Force)
$AudDbStatus = Test-OracleConnection $SAPConfig.Config.AudDbName $SAPConfig.Config.AudDbUser (ConvertTo-SecureString $SAPSecrets.AudDbPassword -AsPlainText -Force)

if ($SysDbStatus -ne 0 -or $AudDbStatus -ne 0) {
  Write-Error "Error testing connection to sys/aud database"
}
