$Scripts = @(
    "../ModPlatformRemoteDesktop/Add-ModPlatformRDServices.ps1",
    "../ModPlatformRemoteDesktop/Set-RDWebPasswordReset.ps1"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Get-Location
$OverallExitCode = 0
foreach ($Script in $Scripts) {
  if ($Script -is [array]) {
    $ScriptCmd = $Script[0]
    $ScriptArg = $Script[1]
    Write-Output ("START $ScriptCmd " + ($ScriptArg | ConvertTo-Json -Compress))
    . $ScriptCmd @ScriptArg
  } else {
    $ScriptCmd = $Script
    Write-Output "START $ScriptCmd"
    . $ScriptCmd
  }
  if ($LASTEXITCODE -eq 3010) {
    Write-Output "REBOOT REQUIRED after $Script - exiting with code 3010"
    Exit 3010  # Exit immediately to allow reboot
  }
  if ($LASTEXITCODE -ne 0) {
    $OverallExitCode = $LASTEXITCODE
    Write-Output "ERROR $ScriptCmd ExitCode=$LASTEXITCODE"
  } else {
    Write-Output "END $ScriptCmd"
  }
  Set-Location $ScriptDir
}
Exit $OverallExitCode
