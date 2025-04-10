function New-TnsOraFile {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $tnsOraFilePath = Join-Path $PSScriptRoot -ChildPath "..\..\Configs\NCR\tnsnames_nart_client.ora"

    if (Test-Path $tnsOraFilePath) {
        Write-Host "Tnsnames.ora file found at $tnsOraFilePath"
    }
    else {
        Write-Error "Tnsnames.ora file not found at $tnsOraFilePath"
        exit 1
    }

    # check if ORACLE_HOME env var exists, if it does then use that. If not then set it from the Config values.

    if (-not $env:ORACLE_HOME) {
        [Environment]::SetEnvironmentVariable("ORACLE_HOME", $Config.ORACLE_19C_HOME, [System.EnvironmentVariableTarget]::Machine)
        $env:ORACLE_HOME = $Config.ORACLE_19C_HOME  # Set in current session
    }

    $tnsOraFileDestination = "$($env:ORACLE_HOME)\network\admin\tnsnames.ora"

    Copy-Item -Path $tnsOraFilePath -Destination $tnsOraFileDestination -Force

}
