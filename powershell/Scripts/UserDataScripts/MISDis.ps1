$Scripts = @(
  @{ Path = '../Common/Set-TimezoneGMT.ps1'; Args = @{} },
  @{ Path = '../Common/Set-LoginText.ps1'; Args = @{} },
  @{ Path = '../Common/Set-WindowsFirewallPortOpenInbound.ps1'; Args = @{ Port = 8080 } }, # Required for LB connections
  @{ Path = '../Common/Set-LocalFirewallOff.ps1'; Args = @{} }, # Required for BODS services Automatic (delayed start) to succeed
  @{ Path = '../Oracle/Install-Oracle19cClient.ps1'; Args = @{} },
  @{ Path = '../Oracle/Set-TnsOraFile.ps1'; Args = @{} },
  @{ Path = '../Oracle/Install-SQLDeveloper.ps1'; Args = @{} },
  @{ Path = '../MISDis/Move-ComputerDeliusInternalAD.ps1'; Args = @{} },
  @{ Path = '../Common/Test-InstallationEscalation.ps1'; Args = @{} },
  @{ Path = '../Common/Install-WinRAR.ps1'; Args = @{} },
  @{ Path = '../Oracle/Test-DbCredentials.ps1'; Args = @{} },
  @{ Path = '../Oracle/Install-IPS.ps1'; Args = @{} },
  @{ Path = '../Oracle/Install-DataServices.ps1'; Args = @{} },
  @{ Path = '../Common/Set-ServiceAutoDelayedStart.ps1'; Args = @{ Services = @('SAP Data Services', 'Server Intelligence Agent*', 'Apache Tomcat*') } }
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Get-Location
$OverallExitCode = 0
foreach ($Script in $Scripts) {
  $scriptPath = $Script.Path
  $scriptArgs = $Script.Args
  Write-Output "START $scriptPath"
  if ($scriptArgs.Count -gt 0) {
    & $scriptPath @scriptArgs
  }
  else {
    . $scriptPath
  }
  if ($LASTEXITCODE -eq 3010) {
    Write-Output "REBOOT REQUIRED after $scriptPath - exiting with code 3010"
    exit 3010  # Exit immediately to allow reboot
  }
  if ($LASTEXITCODE -ne 0) {
    $OverallExitCode = $LASTEXITCODE
    Write-Output "ERROR $scriptPath ExitCode=$LASTEXITCODE"
  }
  else {
    Write-Output "END $scriptPath"
  }
  Set-Location $ScriptDir
}
exit $OverallExitCode
