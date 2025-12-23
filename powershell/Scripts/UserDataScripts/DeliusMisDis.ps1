$Scripts = @(
    "../Common/Set-LoginText.ps1",
    "../Common/Set-LocalFirewallOff.ps1",
    "../Common/Set-IPv4Preferred.ps1",
    "../Common/Set-TimezoneGMT.ps1",
    "../ModPlatformAD/Join-ModPlatformAD.ps1",
    "../Microsoft/Install-ADRemoteTools.ps1",
    #"../Microsoft/Add-DnsSuffixSearchList.ps1",
    "../Microsoft/Remove-EdgeFirstRunExperience.ps1",
    "../Microsoft/Remove-StartMenuShutdownOption.ps1",
    #"../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1",
    "../ModPlatformAD/Add-ModPlatformADUsers.ps1",
    "../Oracle/Install-Oracle19cClient.ps1",
    "../Oracle/Set-TnsOraFile.ps1",
    "../Oracle/Install-SQLDeveloper.ps1",
    "../Common/Install-WinRAR.ps1",
    "../Common/Set-LocalPolicies.ps1",
    "../ModPlatformSAP/Test-ModPlatformSAPDatabaseConnection.ps1"
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
