$Scripts = @(
    "../Common/Set-TimezoneGMT.ps1", # working
    "../Common/Set-LoginText.ps1", # working
    "../Oracle/Install-Oracle19cClient.ps1", # working
    "../Oracle/Set-TnsOraFileMISDis.ps1", # working
    "../Oracle/Install-SQLDeveloper.ps1", # working
    "../MISDis/Move-ComputerDeliusInternalAD.ps1" # working
    "../Oracle/Test-DbCredentials-MISDIS-DEV-ONLY.ps1", # <- testing
    "../Oracle/Install-IPS-MISDIS-DEV-ONLY.ps1", #, <- testing
    "../Oracle/Install-DataServices-MISDIS-DEV-ONLY.ps1" # <- testing
    <#
    New-SharedDriveShortcut -Config $Config <- required?? Possibly - TBD
    New-ServerRebootSchedule -Config $Config <- required?? No - also what is this?
    #>
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
