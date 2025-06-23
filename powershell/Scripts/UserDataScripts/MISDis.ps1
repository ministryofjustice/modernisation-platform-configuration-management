$Scripts = @(
    "../Common/Set-TimezoneGMT.ps1",
    # "../SAP/Get-WindowsMISSoftware.ps1", superseded by installer script
    "../Oracle/Install-Oracle19cClient.ps1",
    "../Oracle/Install-SQLDeveloper.ps1",
    "../MISDis/Move-ComputerDeliusInternalAD.ps1"

    <#
    Install-Oracle19cClient -Config $Config
    New-TnsOraFile -Config $Config
    Test-DbCredentials -Config $Config
    Install-IPS -Config $Config
    Install-DataServices -Config $Config
    Set-LoginText -Config $Config
    New-SharedDriveShortcut -Config $Config
    New-ServerRebootSchedule
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
