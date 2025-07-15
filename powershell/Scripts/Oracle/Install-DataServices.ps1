# Install-DataServices.ps1 - Updated to use Unified Configuration System
# This script installs SAP Data Services using the unified config and response file templates

# Import required modules and functions
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

    $s3Params = @{
        BucketName = $Config.WindowsClientS3Bucket
        Key        = ($Config.WindowsClientS3Folder + '/' + $Key)
        File       = $Destination
        Verbose    = $true
    }

    Read-S3Object @s3Params
}

function Install-DataServices {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    Write-Host '=== Starting Data Services Installation with Unified Config System ===' -ForegroundColor Green

    # Check if already installed
    if (Get-Package | Where-Object { $_.Name -like 'SAP Data Services*' }) {
        Write-Output 'Data Services is already installed'
        return
    }

    $WorkingDirectory = $Config.WorkingDirectory
    Set-Location -Path $WorkingDirectory

    # Download installer
    Write-Host "Downloading Data Services installer: $($Config.DataServicesS3File)" -ForegroundColor Cyan
    Get-Installer -Key $Config.DataServicesS3File -Destination ('.\' + $Config.DataServicesS3File) -Config $Config

    # Handle different extraction/execution methods based on file type and application
    Write-Host 'Preparing installer...' -ForegroundColor Cyan
    if ($Config.DataServicesS3File -match '\.ZIP$') {
        Write-Host 'Extracting ZIP archive...' -ForegroundColor Yellow
        Expand-Archive -Path ('.\' + $Config.DataServicesS3File) -Destination '.\DataServices'
        $dataServicesInstallerFilePath = "$WorkingDirectory\DataServices\setup.exe"
    }
    elseif ($Config.DataServicesS3File -match '\.EXE$') {
        if ($Config.application -eq 'delius-mis') {
            # For Delius MIS, extract with unrar
            Write-Host 'Extracting .EXE with unrar for MISDis...' -ForegroundColor Yellow
            if (Get-Command unrar -ErrorAction SilentlyContinue) {
                unrar x -r -o+ -y ('.\' + $Config.DataServicesS3File) '.\DataServices'
                $dataServicesInstallerFilePath = "$WorkingDirectory\DataServices\setup.exe"
            }
            else {
                Write-Warning 'unrar not available. Please install unrar first.'
                return
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

    # Verify installer exists
    if (-not(Test-Path $dataServicesInstallerFilePath)) {
        Write-Error "Data Services installer not found at $dataServicesInstallerFilePath"
        return
    }

    # Set environment variables
    Write-Host 'Setting environment variables...' -ForegroundColor Cyan
    [Environment]::SetEnvironmentVariable('LINK_DIR', $Config.LINK_DIR, [System.EnvironmentVariableTarget]::Machine)

    if (-not(Test-Path $Config.dscommondir)) {
        Write-Host "Creating DS common directory: $($Config.dscommondir)" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $Config.dscommondir -Force | Out-Null
    }
    [Environment]::SetEnvironmentVariable('DS_COMMON_DIR', $Config.dscommondir, [System.EnvironmentVariableTarget]::Machine)

    # Determine node type
    # Handle MISDis naming convention where EC2 Name tag uses 'delius-mis' but config uses 'ndmis'
    $normalizedNodeName = if ($Config.application -eq 'delius-mis') {
        $Config.Name -replace 'delius-mis', 'ndmis'
    }
    else {
        $Config.Name
    }
    
    $nodeType = if ($normalizedNodeName -eq $Config.NodeConfig.cmsPrimaryNode) { 'primary' } else { 'secondary' }
    Write-Host "Node type determined: $nodeType" -ForegroundColor Cyan
    Write-Host "Current node (normalized): $normalizedNodeName" -ForegroundColor Gray
    Write-Host "Primary node: $($Config.NodeConfig.cmsPrimaryNode)" -ForegroundColor Gray

    # Generate response file using unified system
    $templateName = if ($nodeType -eq 'primary') { 'DataServices_Primary_Template.ini' } else { 'DataServices_Secondary_Template.ini' }
    Write-Host "Generating response file from template: $templateName" -ForegroundColor Cyan
    
    try {
        $responseFileResult = New-ResponseFileFromTemplate -Config $Config -TemplateName $templateName -OutputPath '.\ds_install.ini'
        Write-Host 'Response file generated successfully: .\ds_install.ini' -ForegroundColor Green
        Write-Host "Command line arguments: $($responseFileResult.CommandLineArgs.Count) parameters" -ForegroundColor Gray
    }
    catch {
        Write-Error "Failed to generate response file: $_"
        return
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
        $process = Start-Process @dataServicesInstallParams
        
        $installProcessId = $process.Id
        $exitCode = $process.ExitCode
        
        "Process ID: $installProcessId" | Out-File -FilePath $logFile -Append
        "Exit Code: $exitCode" | Out-File -FilePath $logFile -Append
        "Completed at: $(Get-Date)" | Out-File -FilePath $logFile -Append

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
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $Config = Get-Config
        Write-Host "Configuration loaded for: $($Config.application)" -ForegroundColor Green
        Write-Host "Environment: $($Config.Name)" -ForegroundColor Gray
        Write-Host "Working Directory: $($Config.WorkingDirectory)" -ForegroundColor Gray
        Write-Host "DS Common Directory: $($Config.dscommondir)" -ForegroundColor Gray
        
        Install-DataServices -Config $Config
    }
    catch {
        Write-Error "Failed to execute Install-DataServices: $_"
        Write-Error "Stack Trace: $($_.ScriptStackTrace)"
        exit 1
    }
}