# Install-IPS.ps1 - Updated to use Unified Configuration System
# This script installs SAP Information Platform Services using the unified config and response file templates

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

function Clear-PendingFileRenameOperations {
    $regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
    $regKey = 'PendingFileRenameOperations'

    if (Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction SilentlyContinue) {
        try {
            Remove-ItemProperty -Path $regPath -Name $regKey -Force -ErrorAction Stop
            Write-Host "Successfully removed $regKey from the registry."
        }
        catch {
            Write-Warning "Failed to remove $regKey. Error: $_"
        }
    }
    else {
        Write-Host "$regKey does not exist in the registry. No action needed."
    }
}

function Install-IPS {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )

    Write-Host '=== Starting IPS Installation with Unified Config System ===' -ForegroundColor Green

    $WorkingDirectory = $Config.WorkingDirectory
    Set-Location -Path $WorkingDirectory

    # Check if already installed
    if (Test-Path "$WorkingDirectory\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0") {
        Write-Output 'IPS is already installed'
        return
    }

    # Download and extract installer
    Write-Host "Downloading IPS installer: $($Config.IPSS3File)" -ForegroundColor Cyan
    Get-Installer -Key $Config.IPSS3File -Destination ('.\' + $Config.IPSS3File) -Config $Config
    
    # Handle different extraction methods based on file type
    Write-Host 'Extracting installer...' -ForegroundColor Cyan
    if ($Config.IPSS3File -match '\.ZIP$') {
        Expand-Archive ('.\' + $Config.IPSS3File) -Destination '.\IPS'
    }
    else {
        # For .EXE files that need unrar (MISDis case)
        if (Get-Command unrar -ErrorAction SilentlyContinue) {
            Write-Host 'Using unrar to extract .EXE file' -ForegroundColor Yellow
            unrar x -r -o+ -y ('.\' + $Config.IPSS3File) '.\IPS'
        }
        else {
            Write-Warning 'unrar not available for extracting .EXE file. Attempting self-extraction...'
            Start-Process -FilePath ('.\' + $Config.IPSS3File) -ArgumentList '-s', '-x', '.\IPS' -Wait -NoNewWindow
        }
    }

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
    $templateName = if ($nodeType -eq 'primary') { 'IPS_Primary_Template.ini' } else { 'IPS_Secondary_Template.ini' }
    Write-Host "Generating response file from template: $templateName" -ForegroundColor Cyan
    
    try {
        $responseFileResult = New-ResponseFileFromTemplate -Config $Config -TemplateName $templateName -OutputPath '.\IPS\ips_install.ini'
        Write-Host 'Response file generated successfully: .\IPS\ips_install.ini' -ForegroundColor Green
        Write-Host "Command line arguments: $($responseFileResult.CommandLineArgs.Count) parameters" -ForegroundColor Gray
    }
    catch {
        Write-Error "Failed to generate response file: $_"
        return
    }

    # Clear pending file operations
    Clear-PendingFileRenameOperations

    # Verify setup.exe exists
    $setupExe = '.\IPS\setup.exe'
    if (-not(Test-Path $setupExe)) {
        Write-Error "IPS setup.exe not found at $($setupExe)"
        return
    }

    # Create log file
    $logFile = '.\IPS\install_ips_unified.log'
    New-Item -Type File -Path $logFile -Force | Out-Null

    # Add Oracle client path to the PowerShell session
    $env:Path += ";$($Config.ORACLE_19C_HOME)\bin"
    Write-Host "Oracle client path added: $($Config.ORACLE_19C_HOME)\bin" -ForegroundColor Gray

    Write-Host "Starting IPS installer at $(Get-Date)" -ForegroundColor Green

    try {
        '=== IPS Installation Log - Unified Config System ===' | Out-File -FilePath $logFile -Append
        "Started at: $(Get-Date)" | Out-File -FilePath $logFile -Append
        "Node Type: $nodeType" | Out-File -FilePath $logFile -Append
        "Template Used: $templateName" | Out-File -FilePath $logFile -Append
        '' | Out-File -FilePath $logFile -Append
        
        # Build installer arguments
        $installArgs = @('/wait', '-r .\IPS\ips_install.ini') + $responseFileResult.CommandLineArgs
        
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
        
        # $process = Start-Process -FilePath $setupExe -ArgumentList $installArgs -Wait -NoNewWindow -Verbose -PassThru
        
        # $installProcessId = $process.Id
        # $exitCode = $process.ExitCode
        
        # "Process ID: $installProcessId" | Out-File -FilePath $logFile -Append
        # "Exit Code: $exitCode" | Out-File -FilePath $logFile -Append
        # "Completed at: $(Get-Date)" | Out-File -FilePath $logFile -Append
        
        if ($exitCode -eq 0) {
            Write-Host 'IPS installation completed successfully!' -ForegroundColor Green
        }
        else {
            Write-Warning "IPS installation completed with exit code: $exitCode"
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
    }
    
    Write-Host "IPS installation process completed. Check log file: $logFile" -ForegroundColor Yellow
}

# Main execution block
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $Config = Get-Config
        Write-Host "Configuration loaded for: $($Config.application)" -ForegroundColor Green
        Write-Host "Environment: $($Config.Name)" -ForegroundColor Gray
        Write-Host "Working Directory: $($Config.WorkingDirectory)" -ForegroundColor Gray
        
        Install-IPS -Config $Config
    }
    catch {
        Write-Error "Failed to execute Install-IPS: $_"
        Write-Error "Stack Trace: $($_.ScriptStackTrace)"
        exit 1
    }
}