function Install-Oracle19cClient {

    # Check if Oracle 19c client is already installed
    if (Test-Path $ORACLE_19C_HOME) {
        Write-Verbose "Oracle 19c client is already installed."
        return
    } elseif ($WhatIfPreference) {
        Write-Output "What-If: Installing Oracle 19c client"
        return
    }

    Write-Output "Installing Oracle 19c client"

    $WorkingDirectory = "C:\Software"
    $AppDirectory = "C:\App"

    if (-not (Test-Path $WorkingDirectory)) {
        Write-Output " - Creating directory: $WorkingDirectory"
        New-Item -ItemType Directory -Path $WorkingDirectory -Force | Out-Null
    }

    if (-not (Test-Path $AppDirectory)) {
        Write-Output " - Creating directory: $AppDirectory"
        New-Item -ItemType Directory -Path $AppDirectory -Force | Out-Null
    }

    Set-Location -Path $WorkingDirectory

    # Prepare installer
    Get-Installer -Key $Oracle19c64bitClientS3File -Destination (".\" + $Oracle19c64bitClientS3File) | Out-Null

    Write-Output " - Extracting Archive to .\OracleClient"
    Expand-Archive (".\" + $Oracle19c64bitClientS3File) -Destination ".\OracleClient" | Out-Null

    # Create response file for silent install
    $oracleClientResponseFileContent = @"
oracle.install.responseFileVersion=/oracle/install/rspfmt_clientinstall_response_schema_v19.0.0
ORACLE_HOME=$ORACLE_19C_HOME
ORACLE_BASE=$ORACLE_BASE
oracle.install.IsBuiltInAccount=true
oracle.install.client.installType=Administrator
"@

    Write-Output " - Creating ResponseFile client_install.rsp"
    $oracleClientResponseFileContent | Out-File -FilePath "$WorkingDirectory\OracleClient\client\client_install.rsp" -Force -Encoding ascii

    # Install Oracle 19c client
    $OracleClientInstallParams = @{
        FilePath         = "$WorkingDirectory\OracleClient\client\setup.exe"
        WorkingDirectory = "$WorkingDirectory\OracleClient\client"
        ArgumentList     = "-silent", "-noconfig", "-nowait", "-responseFile $WorkingDirectory\OracleClient\client\client_install.rsp"
        Wait             = $true
        NoNewWindow      = $true
    }

    Write-Output " - Starting silent install: setup.exe"
    Start-Process @OracleClientInstallParams

    # Install Oracle configuration tools
    $oracleConfigToolsParams = @{
        FilePath         = "$WorkingDirectory\OracleClient\client\setup.exe"
        WorkingDirectory = "$WorkingDirectory\OracleClient\client"
        ArgumentList     = "-executeConfigTools", "-silent", "-nowait", "-responseFile $WorkingDirectory\OracleClient\client\client_install.rsp"
        Wait             = $true
        NoNewWindow      = $true
    }

    Write-Output " - Starting silent install: setup.exe -executeConfigTools"
    Start-Process @oracleConfigToolsParams

    # Set environment variable
    Write-Output " - Setting ORACLE_HOME environment variable $ORACLE_19C_HOME"
    [Environment]::SetEnvironmentVariable("ORACLE_HOME", $ORACLE_19C_HOME, [System.EnvironmentVariableTarget]::Machine)
}

function Get-Installer {
    param (
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $s3Params = @{
        BucketName = $S3Bucket
        Key        = ($WindowsClientS3Folder + "/" + $Key)
        File       = $Destination
        Verbose    = $true
    }

    Write-Output " - Retrieving installer from S3: $S3Bucket/$WindowsClientS3Folder/$Key"
    Read-S3Object @s3Params | Out-Null
}

$S3Bucket                   = "mod-platform-image-artefact-bucket20230203091453221500000001"
$WindowsClientS3Folder      = "hmpps/ncr-packages"
$Oracle19c64bitClientS3File = "WINDOWS.X64_193000_client.zip"
$ORACLE_19C_HOME            = "C:\app\oracle\product\19.0.0\client_1"
$ORACLE_BASE                = "C:\app\oracle"

Install-Oracle19cClient
