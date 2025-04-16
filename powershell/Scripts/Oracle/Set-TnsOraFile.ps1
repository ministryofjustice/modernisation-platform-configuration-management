$AppDirectory = "C:\App"

if (-not (Test-Path $AppDirectory)) {
    New-Item -ItemType Directory -Path $AppDirectory -Force
}

$ORACLE_19C_HOME  = "C:\app\oracle\product\19.0.0\client_1"

$tnsOraFilePath = Join-Path $PSScriptRoot -ChildPath "..\..\Configs\NCR\tnsnames_nart_client.ora"

if (Test-Path $tnsOraFilePath) {
    Write-Host "Tnsnames.ora file found at $tnsOraFilePath"
}
else {
    Write-Error "Tnsnames.ora file not found at $tnsOraFilePath"
    exit 1
}

# check if ORACLE_HOME env var exists, if it does then use that. If not then set it from the variable above.

if (-not $env:ORACLE_HOME) {
    [Environment]::SetEnvironmentVariable("ORACLE_HOME", $ORACLE_19C_HOME, [System.EnvironmentVariableTarget]::Machine)
    $env:ORACLE_HOME = $ORACLE_19C_HOME  # Set in current session
}

$tnsOraFileDestination = "$($env:ORACLE_HOME)\network\admin\tnsnames.ora"

Copy-Item -Path $tnsOraFilePath -Destination $tnsOraFileDestination -Force


