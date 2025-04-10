$Scripts = @(
    "../Common/Init-System.ps1",
    "../RDS/Install-RDSessionHostRole.ps1",
    "../ModPlatformAD/Join-ModPlatformAD.ps1",
    "../ModPlatformAD/Move-ModPlatformADComputer.ps1", # Still needs work
    "../Oracle/Install-SQLDeveloper.ps1", # needs testing
    "../Oracle/Install-Oracle19cClient.ps1", # needs testing
    "../Oracle/Set-TnsOraFile.ps1", # needs testing
    "../SAP/Install-BIPWindowsClient43.ps1" # needs testing
)

$ErrorActionPreference = "Stop"
$ScriptDir = Get-Location
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
  Set-Location $ScriptDir
}
Exit $OverallExitCode

