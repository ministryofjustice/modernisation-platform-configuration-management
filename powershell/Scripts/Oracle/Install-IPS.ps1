# Install-IPS.ps1 - Updated to use Unified Configuration System
# This script installs SAP Information Platform Services using the unified config and response file templates

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

function Get-SecretValue {
    param (
        [Parameter(Mandatory)]
        [string]$SecretId,
        [Parameter(Mandatory)]
        [string]$SecretKey
    )

    try {
        $secretJson = aws secretsmanager get-secret-value --secret-id $SecretId --query SecretString --output text

        if ($null -eq $secretJson -or $secretJson -eq '') {
            Write-Host "The SecretId '$SecretId' does not exist or returned no value."
            return $null
        }

        $secretObject = $secretJson | ConvertFrom-Json

        if (-not $secretObject.PSObject.Properties.Name -contains $SecretKey) {
            Write-Host "The SecretKey '$SecretKey' does not exist in the secret."
            return $null
        }

        return $secretObject.$SecretKey
    }
    catch {
        Write-Host "An error occurred while retrieving the secret: $_"
        return $null
    }
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
    
    # Create working directory if it doesn't exist
    if (-not(Test-Path $WorkingDirectory)) {
        Write-Host "Creating working directory: $WorkingDirectory" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $WorkingDirectory -Force | Out-Null
        Write-Host 'Working directory created successfully' -ForegroundColor Green
    }
    
    Set-Location -Path $WorkingDirectory

    # Check if already installed
    $ipsInstallPath = "$WorkingDirectory\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0"
    Write-Host "Checking if IPS is already installed at: $ipsInstallPath" -ForegroundColor Gray
    if (Test-Path $ipsInstallPath) {
        Write-Host 'IPS is already installed - skipping installation' -ForegroundColor Yellow
        return
    }
    Write-Host 'IPS not found - proceeding with installation' -ForegroundColor Green

    # Download and extract installer
    Write-Host "Downloading IPS installer: $($Config.IPSS3File)" -ForegroundColor Cyan
    Write-Host "From S3 bucket: $($Config.WindowsClientS3Bucket)/$($Config.WindowsClientS3Folder)" -ForegroundColor Gray
    Get-Installer -Key $Config.IPSS3File -Destination ('.\' + $Config.IPSS3File) -Config $Config
    Write-Host "Download completed: $($Config.IPSS3File)" -ForegroundColor Green
    
    # Create IPS extraction directory
    $extractionDir = '.\IPS'
    if (-not(Test-Path $extractionDir)) {
        Write-Host "Creating extraction directory: $extractionDir" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $extractionDir -Force | Out-Null
    }

    # Handle different extraction methods based on file type
    Write-Host 'Extracting installer...' -ForegroundColor Cyan
    if ($Config.IPSS3File -match '\.ZIP$') {
        Write-Host 'Extracting ZIP archive...' -ForegroundColor Yellow
        Expand-Archive ('.\' + $Config.IPSS3File) -Destination $extractionDir
    }
    else {
        # For .EXE files that need unrar (MISDis case)
        Write-Host 'Checking for unrar command...' -ForegroundColor Yellow
        if (Get-Command unrar -ErrorAction SilentlyContinue) {
            Write-Host 'Using unrar to extract .EXE file' -ForegroundColor Green
            $unrarResult = & unrar x -r -o+ -y ('.\' + $Config.IPSS3File) $extractionDir
            Write-Host "unrar completed with result: $unrarResult" -ForegroundColor Gray
        }
        else {
            Write-Error 'unrar command not found on PATH. WinRAR should have been installed by Install-WinRAR.ps1 script.'
            Write-Error 'Please ensure Install-WinRAR.ps1 ran successfully before this script.'
            $global:LASTEXITCODE = 1
            throw 'unrar command not available - WinRAR installation required'
        }
    }
    
    Write-Host 'Extraction completed' -ForegroundColor Green

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
        
        # Show the generated response file content
        if (Test-Path '.\IPS\ips_install.ini') {
            Write-Host 'Generated response file content:' -ForegroundColor Yellow
            Write-Host '=================================' -ForegroundColor Yellow
            Get-Content '.\IPS\ips_install.ini' | ForEach-Object {
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
        Write-Error 'Output path: .\IPS\ips_install.ini'
        $global:LASTEXITCODE = 1
        throw $_
    }

    # Clear pending file operations
    Clear-PendingFileRenameOperations

    # Verify setup.exe exists
    $setupExe = '.\IPS\setup.exe'
    Write-Host "Checking for setup.exe at: $setupExe" -ForegroundColor Yellow
    if (-not(Test-Path $setupExe)) {
        Write-Error "IPS setup.exe not found at $($setupExe)"
        Write-Host 'Contents of IPS directory:' -ForegroundColor Yellow
        if (Test-Path '.\IPS') {
            Get-ChildItem '.\IPS' -Recurse | ForEach-Object {
                Write-Host "  $($_.FullName)" -ForegroundColor Gray
            }
        }
        else {
            Write-Host '  IPS directory does not exist' -ForegroundColor Red
        }
        $global:LASTEXITCODE = 1
        throw 'IPS setup.exe not found after extraction'
    }
    Write-Host 'Found setup.exe successfully' -ForegroundColor Green

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
        
        # Get required password values from secrets using existing configuration structure
        Write-Host 'Retrieving password values from secrets...' -ForegroundColor Cyan
        
        # Determine secret ID and key based on configuration structure
        if ($Config.SecretConfig.ContainsKey('secretIds') -and $Config.SecretConfig.ContainsKey('secretKeys')) {
            # MISDis-style explicit configuration
            Write-Host '   Using MISDis-style explicit secret configuration' -ForegroundColor Cyan
            $bodsSecretId = $Config.SecretConfig.secretIds.serviceAccounts
            $bodsAdminPasswordKey = $Config.SecretConfig.secretKeys.bodsAdminPassword
            $sysDbSecretId = $Config.SecretConfig.secretIds.sysDbSecrets
            $audDbSecretId = $Config.SecretConfig.secretIds.audDbSecrets
            $sysDbPasswordKey = $Config.SecretConfig.secretKeys.sysDbUserPassword
            $audDbPasswordKey = $Config.SecretConfig.secretKeys.audDbUserPassword
        }
        else {
            # NCR/ONR-style pattern-based configuration with sensible defaults
            Write-Host '   Using NCR/ONR-style pattern-based secret configuration' -ForegroundColor Cyan
            $bodsAdminPasswordKey = 'bods_admin_password'  # Standard key
            $bodsSecretId = $Config.SecretConfig.secretMappings.bodsSecretName -replace '\{dbenv\}', $Config.dbenv
            
            # For NCR/ONR, both system and audit DB secrets come from the same database-specific secret
            $sysDbSecretId = $Config.SecretConfig.secretMappings.sysDbSecretName -replace '\{sysDbName\}', $Config.DatabaseConfig.sysDbName
            $audDbSecretId = $Config.SecretConfig.secretMappings.audDbSecretName -replace '\{audDbName\}', $Config.DatabaseConfig.audDbName
            
            # Use standard IPS database password keys
            $sysDbPasswordKey = 'bods_ips_system_owner'  # Standard IPS system DB key
            $audDbPasswordKey = 'bods_ips_audit_owner'   # Standard IPS audit DB key
        }
        
        # Debug output to help identify empty values
        Write-Host "   BODS Secret ID: '$bodsSecretId'" -ForegroundColor Gray
        Write-Host "   BODS Admin Key: '$bodsAdminPasswordKey'" -ForegroundColor Gray
        Write-Host "   System DB Secret ID: '$sysDbSecretId'" -ForegroundColor Gray
        Write-Host "   System DB Key: '$sysDbPasswordKey'" -ForegroundColor Gray
        Write-Host "   Audit DB Secret ID: '$audDbSecretId'" -ForegroundColor Gray
        Write-Host "   Audit DB Key: '$audDbPasswordKey'" -ForegroundColor Gray
        
        # Validate that required secret IDs are not empty
        if ([string]::IsNullOrEmpty($bodsSecretId)) {
            throw 'BODS Secret ID is empty. Check SecretConfig.secretMappings.bodsSecretName and dbenv configuration.'
        }
        if ([string]::IsNullOrEmpty($sysDbSecretId)) {
            throw 'System DB Secret ID is empty. Check SecretConfig.secretMappings.sysDbSecretName and DatabaseConfig.sysDbName configuration.'
        }
        if ([string]::IsNullOrEmpty($audDbSecretId)) {
            throw 'Audit DB Secret ID is empty. Check SecretConfig.secretMappings.audDbSecretName and DatabaseConfig.audDbName configuration.'
        }
        
        if ($nodeType -eq 'primary') {
            # Primary node needs CMS, auditing, and CMS DB passwords
            $bods_cluster_key = Get-SecretValue -SecretId $bodsSecretId -SecretKey $bodsAdminPasswordKey
            $bods_ips_audit_owner = Get-SecretValue -SecretId $audDbSecretId -SecretKey $audDbPasswordKey
            $bods_ips_system_owner = Get-SecretValue -SecretId $sysDbSecretId -SecretKey $sysDbPasswordKey
            
            # Build installer arguments for primary node
            $installArgs = @('/wait', '-r .\IPS\ips_install.ini', "cmspassword=$bods_cluster_key", "existingauditingdbpassword=$bods_ips_audit_owner", "existingcmsdbpassword=$bods_ips_system_owner") + $responseFileResult.CommandLineArgs
        }
        else {
            # Secondary node needs remote CMS admin and CMS DB passwords
            $bods_cluster_key = Get-SecretValue -SecretId $bodsSecretId -SecretKey $bodsAdminPasswordKey
            $bods_ips_system_owner = Get-SecretValue -SecretId $sysDbSecretId -SecretKey $sysDbPasswordKey
            
            # Build installer arguments for secondary node
            $installArgs = @('/wait', '-r .\IPS\ips_install.ini', "remotecmsadminpassword=$bods_cluster_key", "existingcmsdbpassword=$bods_ips_system_owner") + $responseFileResult.CommandLineArgs
        }
        
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
        
        $process = Start-Process -FilePath $setupExe -ArgumentList $installArgs -Wait -NoNewWindow -Verbose -PassThru
        
        $installProcessId = $process.Id
        $exitCode = $process.ExitCode
        
        "Process ID: $installProcessId" | Out-File -FilePath $logFile -Append
        "Exit Code: $exitCode" | Out-File -FilePath $logFile -Append
        "Completed at: $(Get-Date)" | Out-File -FilePath $logFile -Append
        
        # For testing purposes, simulate successful completion
        # Write-Host 'TESTING MODE: IPS installer execution skipped' -ForegroundColor Magenta
        # $exitCode = 0
        
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
        Write-Error $errorMsg -ErrorAction Continue
        
        $errorMsg | Out-File -FilePath $logFile -Append
        if ($exception.InnerException) {
            "Inner Exception: $($exception.InnerException.Message)" | Out-File -FilePath $logFile -Append
        }
        "Stack Trace: $($_.ScriptStackTrace)" | Out-File -FilePath $logFile -Append
        $global:LASTEXITCODE = 1
        return
    }
    
    Write-Host "IPS installation process completed. Check log file: $logFile" -ForegroundColor Yellow
}

# Main execution block
try {
    Write-Host 'Loading configuration for IPS installation...' -ForegroundColor Yellow
    $Config = Get-Config
    Write-Host "Configuration loaded for: $($Config.application)" -ForegroundColor Green
    Write-Host "Environment: $($Config.EnvironmentName)" -ForegroundColor Gray
    Write-Host "Machine Name: $($Config.Name)" -ForegroundColor Gray
    Write-Host "Working Directory: $($Config.WorkingDirectory)" -ForegroundColor Gray
    Write-Host "IPS S3 File: $($Config.IPSS3File)" -ForegroundColor Gray
    if ($Config.ContainsKey('ConfigKey')) {
        Write-Host "Config Key: $($Config.ConfigKey)" -ForegroundColor Gray
    }
    if ($Config.ContainsKey('ClusterName')) {
        Write-Host "Cluster: $($Config.ClusterName)" -ForegroundColor Gray
    }
    
    Write-Host 'Starting IPS installation process...' -ForegroundColor Yellow
    Install-IPS -Config $Config
    Write-Host 'IPS installation process completed.' -ForegroundColor Green
    $global:LASTEXITCODE = 0
}
catch {
    $errorMessage = "Failed to execute Install-IPS: $($_.Exception.Message)"
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