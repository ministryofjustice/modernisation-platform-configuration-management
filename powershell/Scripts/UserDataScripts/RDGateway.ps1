$Scripts = @(
    "../Common/Set-LocalFirewallOff.ps1",
    "../Common/Set-IPv4Preferred.ps1",
    "../Common/Set-GMTTimezone.ps1",
    "../ModPlatformAD/Join-ModPlatformAD.ps1 -NewHostname keep-existing",
    "../Microsoft/Add-DnsSuffixSearchList.ps1",
    "../Microsoft/Remove-EdgeFirstRunExperience.ps1",
    "../Microsoft/Remove-StartMenuShutdownOption.ps1",
    "../ModPlatformRemoteDesktop/Add-ModPlatformRDGateway.ps1 -EnableSSLBridging $false",
    "../ModPlatformAD/Move-ModPlatformADComputer.ps1",
    "../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Get-Location
$OverallExitCode = 0
foreach ($Script in $Scripts) {
  Write-Output "START $Script"
  . $Script
  if ($LASTEXITCODE -eq 3010) {
    Write-Output "REBOOT REQUIRED after $Script - exiting with code 3010"
    Exit 3010  # Exit immediately to allow reboot
  }
  if ($LASTEXITCODE -ne 0) {
    $OverallExitCode = $LASTEXITCODE
    Write-Output "ERROR $Script ExitCode=$LASTEXITCODE"
  } else {
    Write-Output "END $Script"
  }
  Set-Location $ScriptDir
}
Exit $OverallExitCode
