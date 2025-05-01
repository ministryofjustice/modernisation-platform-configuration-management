$Scripts = @(
    "../Common/Set-LocalFirewallOff.ps1",
    "../Common/Set-IPv4Preferred.ps1",
    "../Common/Set-TimezoneGMT.ps1",
    "../Common/Set-PermanentPSModulePath.ps1",
    "../Common/Install-Putty.ps1",
    "../Common/Install-WinSCP.ps1",
    "../ModPlatformAD/Join-ModPlatformAD.ps1",
    "../ModPlatformAD/Move-ModPlatformADComputer.ps1",
    "../Oracle/Install-Java6.ps1",
    "../Oracle/Install-Java8.ps1",
    "../Oracle/Install-JavaDeployment.ps1",
    "../Oracle/Install-SQLDeveloper.ps1",
    "../Oracle/Remove-JavaUpdateCheck.ps1",
    "../Microsoft/Add-DnsSuffixSearchList.ps1",
    "../Microsoft/Add-EdgeInternetExplorerIntegration.ps1",
    "../Microsoft/Add-EdgePopupsAllowedForUrls.ps1",
    "../Microsoft/Add-StartMenuShortcuts.ps1",
    "../Microsoft/Install-ADRemoteTools.ps1",
    "../Microsoft/Remove-EdgeFirstRunExperience.ps1",
    "../Microsoft/Remove-StartMenuShutdownOption.ps1",
    "../LibreOffice/Install-LibreOffice.ps1",
    "../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1"
    "../Oracle/Install-Oracle19cClient.ps1",
    "../Oracle/Set-TnsOraFile.ps1",
    "../SAP/Install-BIPWindowsClient43.ps1"
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
