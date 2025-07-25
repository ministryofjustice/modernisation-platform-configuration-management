$Scripts = @(
    "../Common/Set-LocalFirewallOff.ps1",
    "../Common/Set-IPv4Preferred.ps1",
    "../Common/Set-TimezoneGMT.ps1",
    "../ModPlatformAD/Join-ModPlatformAD.ps1",
    # "../ModPlatformAD/Move-ModPlatformADComputer.ps1",
    "../Microsoft/Add-DnsSuffixSearchList.ps1",
    "../Microsoft/Remove-EdgeFirstRunExperience.ps1",
    "../Microsoft/Remove-StartMenuShutdownOption.ps1",
    "../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1"
    # "../ModPlatformRemoteDesktop/Add-ModPlatformRDServices.ps1", # Run this manually as a domain user
    # "../ModPlatformRemoteDesktop/Set-RDWebPasswordReset.ps1",    # Run this manually as a domain user
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
