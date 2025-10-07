$Scripts = @(
  '../Common/Set-TimezoneGMT.ps1',
  '../Common/Set-LoginText.ps1',
  '../Common/Set-WindowsFirewallPortOpenInbound.ps1 -Port 8080',
  '../Oracle/Install-Oracle19cClient.ps1',
  '../Oracle/Set-TnsOraFileMISDis.ps1',
  '../Oracle/Install-SQLDeveloper.ps1',
  '../MISDis/Move-ComputerDeliusInternalAD.ps1',
  '../Common/Test-InstallationEscalation.ps1',
  '../Common/Install-WinRAR.ps1',
  '../Oracle/Test-DbCredentials.ps1',
  '../Oracle/Install-IPS.ps1',
  '../Oracle/Install-DataServices.ps1' 
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Get-Location
$OverallExitCode = 0
foreach ($Script in $Scripts) {
  Write-Output "START $Script"
  . $Script
  if ($LASTEXITCODE -eq 3010) {
    Write-Output "REBOOT REQUIRED after $Script - exiting with code 3010"
    exit 3010  # Exit immediately to allow reboot
  }
  if ($LASTEXITCODE -ne 0) {
    $OverallExitCode = $LASTEXITCODE
    Write-Output "ERROR $Script ExitCode=$LASTEXITCODE"
  }
  else {
    Write-Output "END $Script"
  }
  Set-Location $ScriptDir
}
exit $OverallExitCode
