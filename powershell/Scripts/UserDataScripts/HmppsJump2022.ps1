$Scripts = @(
  "../ModPlatformAD/Join-ModPlatformAD.ps1",
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
)

$ErrorActionPreference = "Stop"
$OverallExitCode = 0
foreach ($Script in $Scripts) {
  Write-Output "START $Script"
  . $Script
  if ($LASTEXITCODE -ne 0) {
    $OverallExitCode = $LASTEXITCODE
    Write-Output "ERROR $Script ExitCode=$LASTEXITCODE"
  } else {
    Write-Output "END   $Script"
  }
}
Exit $OverallExitCode
