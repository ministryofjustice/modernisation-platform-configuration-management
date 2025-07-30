$Scripts = @(
    @{Path = '../MISDis/Move-ComputerDeliusInternalAD.ps1'; Args = @{ServerTypeOverride = 'MISDis' } },
    @{Path = '../Common/Test-InstallationEscalation.ps1'; Args = @{} }
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Get-Location
$OverallExitCode = 0
foreach ($Script in $Scripts) {
    Write-Output "START $($Script.Path)"
    $ScriptArgs = $Script.Args
    & $Script.Path @ScriptArgs
    if ($LASTEXITCODE -eq 3010) {
        Write-Output "REBOOT REQUIRED after $($Script.Path) - exiting with code 3010"
        exit 3010  # Exit immediately to allow reboot
    }
    if ($LASTEXITCODE -ne 0) {
        $OverallExitCode = $LASTEXITCODE
        Write-Output "ERROR $($Script.Path) ExitCode=$LASTEXITCODE"
    }
    else {
        Write-Output "END $($Script.Path)"
    }
    Set-Location $ScriptDir
}
exit $OverallExitCode