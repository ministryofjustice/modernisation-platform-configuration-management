Import-Module ModPlatformSAP -Force

$ErrorActionPreference = "Stop"

$ErrorActionPreference = "Stop"

$SAPConfig  = Get-ModPlatformSAPConfig
$SAPSecrets = Get-ModPlatformSAPSecrets $SAPConfig
$SysDbStatus = Test-OracleConnection $SAPConfig.Variables.SysDbName $SAPConfig.Variables.SysDbUser (ConvertTo-SecureString $SAPSecrets.SysDbPassword -AsPlainText -Force)
$AudDbStatus = Test-OracleConnection $SAPConfig.Variables.AudDbName $SAPConfig.Variables.AudDbUser (ConvertTo-SecureString $SAPSecrets.AudDbPassword -AsPlainText -Force)

if ($SysDbStatus -ne 0 -or $AudDbStatus -ne 0) {
  Write-Error "Error testing connection to sys/aud database"
}
