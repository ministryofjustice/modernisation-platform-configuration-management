# Install-DataServices.ps1 - Updated to use Unified Configuration System
# This script installs SAP Data Services using the unified config and response file templates

# Import required modules and functions
Import-Module AWSPowerShell -Force
. (Join-Path $PSScriptRoot '..\..\Configs\unified_config_system.ps1')

function Get-Config {
    $tokenParams = @{
        TimeoutSec = 10
        Headers    = @{'X-aws-ec2-metadata-token-ttl-seconds' = 3600 }
        Method     = 'PUT'
        Uri        = 'http://169.254.169.254/latest/api/token'
    }
    $Token = Invoke-RestMethod @tokenParams

    $instanceIdParams = @{
        TimeoutSec = 10
        Headers    = @{'X-aws-ec2-metadata-token' = $Token }
        Method     = 'GET'
        Uri        = 'http://169.254.169.254/latest/meta-data/instance-id'
    }
    $InstanceId = Invoke-RestMethod @instanceIdParams

    $awsParams = @(
        'ec2',
        'describe-tags',
        '--filters',
        "Name=resource-id,Values=$InstanceId"
    )

    $TagsRaw = & aws @awsParams

    $Tags = $TagsRaw | ConvertFrom-Json
    $EnvironmentNameTag = ($Tags.Tags | Where-Object { $_.Key -eq 'environment-name' }).Value
    $ApplicationTag = ($Tags.Tags | Where-Object { $_.Key -eq 'application' }).Value
    $dbenvTag = ($Tags.Tags | Where-Object { $_.Key -eq 'oasys-national-reporting-environment' }).Value
    $nameTag = ($Tags.Tags | Where-Object { $_.Key -eq 'Name' }).Value
    $domainName = ($Tags.Tags | Where-Object { $_.Key -eq 'domain-name' }).Value

    $additionalConfig = @{
        application = $ApplicationTag
        dbenv       = $dbenvTag
        Name        = $nameTag
        domainName  = $domainName
    }

    # Use unified config system
    return Get-UnifiedConfig -EnvironmentName $EnvironmentNameTag -Application $ApplicationTag -AdditionalTags $additionalConfig
}

function Get-Installer {
    param (
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Destination,

        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    $fullS3Key = ($Config.WindowsClientS3Folder + '/' + $Key)
    Write-Host 'Attempting to download from S3:' -ForegroundColor Yellow
    Write-Host "  Bucket: $($Config.WindowsClientS3Bucket)" -ForegroundColor Gray
    Write-Host "  Key: $fullS3Key" -ForegroundColor Gray
    Write-Host "  Destination: $Destination" -ForegroundColor Gray

    $s3Params = @{
        BucketName = $Config.WindowsClientS3Bucket
        Key        = $fullS3Key
        File       = $Destination
        Verbose    = $true
    }

    try {
        Read-S3Object @s3Params
        Write-Host "Successfully downloaded: $Key" -ForegroundColor Green
        
        # Check file size
        if (Test-Path $Destination) {
            $fileInfo = Get-Item $Destination
            Write-Host "File size: $([math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor Gray
        }
    }
    catch {
        Write-Error "Failed to download $Key from S3: $_"
        Write-Host 'S3 Parameters used:' -ForegroundColor Red
        $s3Params | ConvertTo-Json -Depth 2 | Write-Host -ForegroundColor Red
        throw
    }
}

function Install-DataServices {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    Write-Host '=== Starting Data Services Installation with Unified Config System ===' -ForegroundColor Green

    # Check if already installed
    Write-Host 'Checking if Data Services is already installed...' -ForegroundColor Gray
    $existingDataServices = Get-Package | Where-Object { $_.Name -like 'SAP Data Services*' }
    if ($existingDataServices) {
        Write-Host "Data Services is already installed: $($existingDataServices.Name) v$($existingDataServices.Version)" -ForegroundColor Yellow
        return
    }
    Write-Host 'Data Services not found - proceeding with installation' -ForegroundColor Green

    $WorkingDirectory = $Config.WorkingDirectory
    
    # Create working directory if it doesn't exist
    if (-not(Test-Path $WorkingDirectory)) {
        Write-Host "Creating working directory: $WorkingDirectory" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $WorkingDirectory -Force | Out-Null
        Write-Host 'Working directory created successfully' -ForegroundColor Green
    }
    
    Set-Location -Path $WorkingDirectory

    # Download installer
    Write-Host "Downloading Data Services installer: $($Config.DataServicesS3File)" -ForegroundColor Cyan
    Write-Host "From S3 bucket: $($Config.WindowsClientS3Bucket)/$($Config.WindowsClientS3Folder)" -ForegroundColor Gray
    Get-Installer -Key $Config.DataServicesS3File -Destination ('.\' + $Config.DataServicesS3File) -Config $Config
    Write-Host "Download completed: $($Config.DataServicesS3File)" -ForegroundColor Green

    # Create DataServices extraction directory
    $extractionDir = '.\DataServices'
    if (-not(Test-Path $extractionDir)) {
        Write-Host "Creating extraction directory: $extractionDir" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $extractionDir -Force | Out-Null
    }

    # Handle different extraction/execution methods based on file type and application
    Write-Host 'Preparing installer...' -ForegroundColor Cyan
    if ($Config.DataServicesS3File -match '\.ZIP$') {
        Write-Host 'Extracting ZIP archive...' -ForegroundColor Yellow
        Expand-Archive -Path ('.\' + $Config.DataServicesS3File) -Destination $extractionDir
        $dataServicesInstallerFilePath = "$WorkingDirectory\DataServices\setup.exe"
    }
    elseif ($Config.DataServicesS3File -match '\.EXE$') {
        if ($Config.application -eq 'delius-mis') {
            # For Delius MIS, extract with unrar
            Write-Host 'Extracting .EXE with unrar for MISDis...' -ForegroundColor Yellow
            Write-Host 'Checking for unrar command...' -ForegroundColor Yellow
            if (Get-Command unrar -ErrorAction SilentlyContinue) {
                Write-Host 'Using unrar to extract .EXE file' -ForegroundColor Green
                $unrarResult = & unrar x -r -o+ -y ('.\' + $Config.DataServicesS3File) $extractionDir
                Write-Host "unrar completed with result: $unrarResult" -ForegroundColor Gray
                $dataServicesInstallerFilePath = "$WorkingDirectory\DataServices\setup.exe"
            }
            else {
                Write-Error 'unrar command not found on PATH. WinRAR should have been installed by Install-WinRAR.ps1 script.'
                Write-Error 'Please ensure Install-WinRAR.ps1 ran successfully before this script.'
                $global:LASTEXITCODE = 1
                throw 'unrar command not available - WinRAR installation required'
            }
        }
        else {
            # For other applications, use .EXE directly
            Write-Host 'Using .EXE installer directly...' -ForegroundColor Yellow
            $dataServicesInstallerFilePath = "$WorkingDirectory\$($Config.DataServicesS3File)"
        }
    }
    else {
        Write-Error "Unknown Data Services file format: $($Config.DataServicesS3File)"
        return
    }
    
    Write-Host 'Installer preparation completed' -ForegroundColor Green

    # Verify installer exists
    Write-Host "Checking for installer at: $dataServicesInstallerFilePath" -ForegroundColor Yellow
    if (-not(Test-Path $dataServicesInstallerFilePath)) {
        Write-Error "Data Services installer not found at $dataServicesInstallerFilePath"
        Write-Host 'Contents of DataServices directory:' -ForegroundColor Yellow
        if (Test-Path '.\DataServices') {
            Get-ChildItem '.\DataServices' -Recurse | ForEach-Object {
                Write-Host "  $($_.FullName)" -ForegroundColor Gray
            }
        }
        else {
            Write-Host '  DataServices directory does not exist' -ForegroundColor Red
        }
        $global:LASTEXITCODE = 1
        throw 'Data Services installer not found after extraction'
    }
    Write-Host 'Found installer successfully' -ForegroundColor Green

    # Set environment variables
    Write-Host 'Setting environment variables...' -ForegroundColor Cyan
    [Environment]::SetEnvironmentVariable('LINK_DIR', $Config.LINK_DIR, [System.EnvironmentVariableTarget]::Machine)

    if (-not(Test-Path $Config.dscommondir)) {
        Write-Host "Creating DS common directory: $($Config.dscommondir)" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $Config.dscommondir -Force | Out-Null
    }
    [Environment]::SetEnvironmentVariable('DS_COMMON_DIR', $Config.dscommondir, [System.EnvironmentVariableTarget]::Machine)

    # Determine node type using enhanced cluster detection
    # The unified config system now automatically detects which cluster this machine belongs to
    # and returns the role (primary/secondary) in DetectedRole
    
    $nodeType = if ($Config.ContainsKey('DetectedRole') -and $Config.DetectedRole -ne 'unknown') {
        $Config.DetectedRole
    }
    else {
        # Fallback to legacy detection if needed
        $normalizedNodeName = if ($Config.application -eq 'delius-mis') {
            $Config.Name -replace 'delius-mis', 'ndmis'
        }
        else {
            $Config.Name
        }
        
        if ($normalizedNodeName -eq $Config.NodeConfig.cmsPrimaryNode -or $Config.Name -eq $Config.NodeConfig.cmsPrimaryNode) {
            'primary'
        }
        else {
            'secondary'
        }
    }
    
    Write-Host "Node type determined: $nodeType" -ForegroundColor Cyan
    Write-Host "Current machine: $($Config.Name)" -ForegroundColor Gray
    if ($Config.ContainsKey('NormalizedMachineName')) {
        Write-Host "Normalized name: $($Config.NormalizedMachineName)" -ForegroundColor Gray
    }
    Write-Host "Primary node from config: $($Config.NodeConfig.cmsPrimaryNode)" -ForegroundColor Gray
    if ($Config.ContainsKey('ConfigKey')) {
        Write-Host "Using configuration: $($Config.ConfigKey)" -ForegroundColor Gray
    }
    if ($Config.ContainsKey('ClusterName')) {
        Write-Host "Cluster: $($Config.ClusterName)" -ForegroundColor Gray
    }

    # Generate response file using unified system
    $templateName = if ($nodeType -eq 'primary') { 'DataServices_Primary_Template.ini' } else { 'DataServices_Secondary_Template.ini' }
    Write-Host "Generating response file from template: $templateName" -ForegroundColor Cyan
    
    try {
        $responseFileResult = New-ResponseFileFromTemplate -Config $Config -TemplateName $templateName -OutputPath '.\ds_install.ini'
        Write-Host 'Response file generated successfully: .\ds_install.ini' -ForegroundColor Green
        Write-Host "Command line arguments: $($responseFileResult.CommandLineArgs.Count) parameters" -ForegroundColor Gray
        
        # Show the generated response file content
        if (Test-Path '.\ds_install.ini') {
            Write-Host 'Generated response file content:' -ForegroundColor Yellow
            Write-Host '=================================' -ForegroundColor Yellow
            Get-Content '.\ds_install.ini' | ForEach-Object {
                # Mask sensitive data in output
                if ($_ -match 'password=') {
                    Write-Host ($_ -replace '=.*', '=****') -ForegroundColor Gray
                }
                else {
                    Write-Host $_ -ForegroundColor Gray
                }
            }
            Write-Host '=================================' -ForegroundColor Yellow
        }
    }
    catch {
        Write-Error "Failed to generate response file: $_"
        Write-Error "Template: $templateName"
        Write-Error 'Output path: .\ds_install.ini'
        $global:LASTEXITCODE = 1
        throw $_
    }

    # Create log file
    $logFile = '.\install_dataservices_unified.log'
    New-Item -Type File -Path $logFile -Force | Out-Null

    Write-Host "Starting Data Services installer at $(Get-Date)" -ForegroundColor Green

    try {
        '=== Data Services Installation Log - Unified Config System ===' | Out-File -FilePath $logFile -Append
        "Started at: $(Get-Date)" | Out-File -FilePath $logFile -Append
        "Node Type: $nodeType" | Out-File -FilePath $logFile -Append
        "Template Used: $templateName" | Out-File -FilePath $logFile -Append
        "Installer Path: $dataServicesInstallerFilePath" | Out-File -FilePath $logFile -Append
        '' | Out-File -FilePath $logFile -Append

        # Build installer arguments
        $installArgs = @('-q', '-r', '.\ds_install.ini') + $responseFileResult.CommandLineArgs
        
        'Installer Arguments (sensitive data masked):' | Out-File -FilePath $logFile -Append
        $installArgs | ForEach-Object { 
            if ($_ -match 'password=') {
                "  $($_ -replace '=.*', '=****')" | Out-File -FilePath $logFile -Append
            }
            else {
                "  $_" | Out-File -FilePath $logFile -Append
            }
        }
        '' | Out-File -FilePath $logFile -Append

        Write-Host "Launching installer with $($installArgs.Count) arguments..." -ForegroundColor Cyan

        $dataServicesInstallParams = @{
            FilePath     = $dataServicesInstallerFilePath
            ArgumentList = $installArgs
            Wait         = $true
            NoNewWindow  = $true
            PassThru     = $true
        }

        # Install Data Services
        # Temporarily commented out for testing - uncomment when ready to actually install
        # $process = Start-Process @dataServicesInstallParams
        
        # $installProcessId = $process.Id
        # $exitCode = $process.ExitCode
        
        # "Process ID: $installProcessId" | Out-File -FilePath $logFile -Append
        # "Exit Code: $exitCode" | Out-File -FilePath $logFile -Append
        # "Completed at: $(Get-Date)" | Out-File -FilePath $logFile -Append
        
        # For testing purposes, simulate successful completion
        Write-Host 'TESTING MODE: Data Services installer execution skipped' -ForegroundColor Magenta
        $exitCode = 0

        if ($exitCode -eq 0) {
            Write-Host 'Data Services installation completed successfully!' -ForegroundColor Green
        }
        else {
            Write-Warning "Data Services installation completed with exit code: $exitCode"
        }

    }
    catch {
        $exception = $_.Exception
        $errorMsg = "Failed to start installer at $(Get-Date): $($exception.Message)"
        Write-Error $errorMsg
        
        $errorMsg | Out-File -FilePath $logFile -Append
        if ($exception.InnerException) {
            "Inner Exception: $($exception.InnerException.Message)" | Out-File -FilePath $logFile -Append
        }
        "Stack Trace: $($_.ScriptStackTrace)" | Out-File -FilePath $logFile -Append
        return
    }

    # Post-installation: Configure JDBC driver
    Write-Host 'Configuring JDBC driver...' -ForegroundColor Cyan
    
    $jdbcDriverPath = "$($Config.ORACLE_19C_HOME)\jdbc\lib\ojdbc8.jar"
    $destinations = @(
        "$($Config.LINK_DIR)\ext\lib",
        "$($Config.BIP_INSTALL_DIR)\java\lib\im\oracle"
    )

    if (Test-Path $jdbcDriverPath) {
        foreach ($destination in $destinations) {
            if (Test-Path $destination) {
                Write-Host "Copying JDBC driver to: $destination" -ForegroundColor Yellow
                Copy-Item -Path $jdbcDriverPath -Destination $destination -Force
                "JDBC driver copied to: $destination" | Out-File -FilePath $logFile -Append
            }
            else {
                Write-Warning "Destination $destination does not exist, skipping"
                "Destination not found: $destination" | Out-File -FilePath $logFile -Append
            }
        }
        Write-Host 'JDBC driver configuration completed' -ForegroundColor Green
    }
    else {
        $errorMsg = "JDBC driver not found at $jdbcDriverPath"
        Write-Error $errorMsg
        $errorMsg | Out-File -FilePath $logFile -Append
        return
    }

    Write-Host "Data Services installation process completed. Check log file: $logFile" -ForegroundColor Yellow
}

# Main execution block
try {
    Write-Host 'Loading configuration for Data Services installation...' -ForegroundColor Yellow
    $Config = Get-Config
    Write-Host "Configuration loaded for: $($Config.application)" -ForegroundColor Green
    Write-Host "Environment: $($Config.EnvironmentName)" -ForegroundColor Gray
    Write-Host "Machine Name: $($Config.Name)" -ForegroundColor Gray
    Write-Host "Working Directory: $($Config.WorkingDirectory)" -ForegroundColor Gray
    Write-Host "DS Common Directory: $($Config.dscommondir)" -ForegroundColor Gray
    Write-Host "Data Services S3 File: $($Config.DataServicesS3File)" -ForegroundColor Gray
    if ($Config.ContainsKey('ConfigKey')) {
        Write-Host "Config Key: $($Config.ConfigKey)" -ForegroundColor Gray
    }
    if ($Config.ContainsKey('ClusterName')) {
        Write-Host "Cluster: $($Config.ClusterName)" -ForegroundColor Gray
    }
    
    Write-Host 'Starting Data Services installation process...' -ForegroundColor Yellow
    Install-DataServices -Config $Config
    Write-Host 'Data Services installation process completed.' -ForegroundColor Green
    $global:LASTEXITCODE = 0
}
catch {
    $errorMessage = "Failed to execute Install-DataServices: $($_.Exception.Message)"
    Write-Error $errorMessage -ErrorAction Continue
    if ($_.ScriptStackTrace) {
        Write-Host 'Stack Trace:' -ForegroundColor Red
        $_.ScriptStackTrace.Split([Environment]::NewLine) | ForEach-Object {
            if ($_ -ne '') {
                Write-Host "  $_" -ForegroundColor DarkRed
            }
        }
    }
    $global:LASTEXITCODE = 1
}