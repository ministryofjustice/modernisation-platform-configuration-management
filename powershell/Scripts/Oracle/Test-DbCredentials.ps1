# Test-DbCredentials-Unified.ps1 - Generic Database Credentials Test using Unified Configuration System
# This script tests database connectivity using the unified config system across all BODS environments

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

function Test-DatabaseConnection {
    param (
        [Parameter(Mandatory = $true)]
        [String]$typePath,
        [Parameter(Mandatory = $true)]
        [String]$tnsName,
        [Parameter(Mandatory = $true)]
        [String]$username,
        [Parameter(Mandatory = $true)]
        [System.Security.SecureString]$securePassword
    )

    Add-Type -Path $typePath

    # Convert SecureString to plain text safely
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    # Create connection string
    $connectionString = "User Id=$username;Password=$plainPassword;Data Source=$tnsName"
    $connection = New-Object Oracle.DataAccess.Client.OracleConnection($connectionString)

    try {
        # Test connection
        $connection.Open()
        Write-Host 'Connection successful!'
        return 0
    }
    catch {
        Write-Host "Connection failed: $($_.Exception.Message)"
        return 1
    }
    finally {
        if ($connection -and $connection.State -eq 'Open') {
            $connection.Close()
        }
        # Clear sensitive data
        if ($BSTR) {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
        }
        $plainPassword = $null
        $connectionString = $null
    }
}

function Test-DbCredentials {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config,
        
        [Parameter()]
        [switch]$TestMode
    )

    Write-Host '=== Starting Database Credentials Test with Unified Config System ===' -ForegroundColor Green
    Write-Host "Application: $($Config.application)" -ForegroundColor Cyan
    Write-Host "Environment: $($Config.EnvironmentName)" -ForegroundColor Cyan
    
    if ($Config.ContainsKey('ClusterName')) {
        Write-Host "Cluster: $($Config.ClusterName)" -ForegroundColor Cyan
    }
    
    Write-Host "Oracle Home: $($Config.ORACLE_19C_HOME)" -ForegroundColor Gray

    # Check database credentials BEFORE installer runs
    $typePath = "$($Config.ORACLE_19C_HOME)\ODP.NET\bin\4\Oracle.DataAccess.dll"

    Write-Host 'Checking Oracle client installation...' -ForegroundColor Yellow
    Write-Host "Oracle Home: $($Config.ORACLE_19C_HOME)" -ForegroundColor Gray
    Write-Host "Expected DLL path: $typePath" -ForegroundColor Gray

    # Verify Oracle client DLL exists
    if (-not (Test-Path $typePath)) {
        Write-Error "Oracle Data Access DLL not found at: $typePath"
        Write-Error "Please ensure Oracle Client is installed at: $($Config.ORACLE_19C_HOME)"
        
        # Check if Oracle home directory exists
        if (Test-Path $Config.ORACLE_19C_HOME) {
            Write-Host 'Oracle home directory exists, checking contents...' -ForegroundColor Yellow
            $oracleContents = Get-ChildItem $Config.ORACLE_19C_HOME -ErrorAction SilentlyContinue
            Write-Host "Oracle home contains: $($oracleContents.Name -join ', ')" -ForegroundColor Gray
        }
        else {
            Write-Error "Oracle home directory does not exist: $($Config.ORACLE_19C_HOME)"
        }
        return 1
    }

    Write-Host "Oracle client DLL found successfully: $typePath" -ForegroundColor Green

    # Get database credentials using unified system
    try {
        Write-Host 'Retrieving database credentials from unified config...' -ForegroundColor Yellow
        Write-Host "System DB User: $($Config.DatabaseConfig.sysDbUser)" -ForegroundColor Gray
        Write-Host "System DB Name: $($Config.DatabaseConfig.sysDbName)" -ForegroundColor Gray
        Write-Host "Audit DB User: $($Config.DatabaseConfig.audDbUser)" -ForegroundColor Gray
        Write-Host "Audit DB Name: $($Config.DatabaseConfig.audDbName)" -ForegroundColor Gray
        
        # Get system database password
        Write-Host "Retrieving password for system DB user: $($Config.DatabaseConfig.sysDbUser)" -ForegroundColor Yellow
        $sysDbPassword = Get-SecretValueUnified -Config $Config -SecretType 'sys_db' -SecretKey $Config.DatabaseConfig.sysDbUser -TestMode:$TestMode
        if (-not $sysDbPassword) {
            Write-Error "Failed to retrieve system database password for user: $($Config.DatabaseConfig.sysDbUser)"
            return 1
        }
        Write-Host 'Successfully retrieved system DB password' -ForegroundColor Green

        # Get audit database password
        Write-Host "Retrieving password for audit DB user: $($Config.DatabaseConfig.audDbUser)" -ForegroundColor Yellow
        $audDbPassword = Get-SecretValueUnified -Config $Config -SecretType 'aud_db' -SecretKey $Config.DatabaseConfig.audDbUser -TestMode:$TestMode
        if (-not $audDbPassword) {
            Write-Error "Failed to retrieve audit database password for user: $($Config.DatabaseConfig.audDbUser)"
            return 1
        }
        Write-Host 'Successfully retrieved audit DB password' -ForegroundColor Green

        Write-Host 'Successfully retrieved all credentials from secrets manager' -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to retrieve database credentials: $_"
        Write-Error "Exception details: $($_.Exception.Message)"
        if ($_.Exception.InnerException) {
            Write-Error "Inner exception: $($_.Exception.InnerException.Message)"
        }
        return 1
    }

    # Define database configurations using unified config values
    $dbConfigs = @(
        @{
            Name     = $Config.DatabaseConfig.sysDbName
            Username = $Config.DatabaseConfig.sysDbUser
            Password = $sysDbPassword
            Type     = 'System'
        },
        @{
            Name     = $Config.DatabaseConfig.audDbName
            Username = $Config.DatabaseConfig.audDbUser
            Password = $audDbPassword
            Type     = 'Audit'
        }
    )

    Write-Host 'Testing connections to databases:' -ForegroundColor Yellow
    foreach ($db in $dbConfigs) {
        Write-Host "  - $($db.Type): $($db.Name) (user: $($db.Username))" -ForegroundColor Gray
    }

    # Test each database connection
    $allTestsPassed = $true
    foreach ($db in $dbConfigs) {
        Write-Host "`nTesting connection to $($db.Type) database: $($db.Name)" -ForegroundColor Cyan
        
        if ($TestMode) {
            Write-Host "TEST MODE: Simulating connection test for $($db.Name)" -ForegroundColor Magenta
            Write-Host "Connection to $($db.Name) successful (TEST MODE)." -ForegroundColor Green
            continue
        }
        
        try {
            $securePassword = ConvertTo-SecureString -String $db.Password -AsPlainText -Force
            $result = Test-DatabaseConnection -typePath $typePath -tnsName $db.Name -username $db.Username -securePassword $securePassword
            
            if ($result -ne 0) {
                Write-Host "Connection to $($db.Type) database ($($db.Name)) failed." -ForegroundColor Red
                $allTestsPassed = $false
            }
            else {
                Write-Host "Connection to $($db.Type) database ($($db.Name)) successful." -ForegroundColor Green
            }
        }
        catch {
            Write-Error "Error testing connection to $($db.Type) database ($($db.Name)): $_"
            $allTestsPassed = $false
        }
    }

    if ($allTestsPassed) {
        Write-Host "`n=== All database connections successful! ===" -ForegroundColor Green
        return 0
    }
    else {
        Write-Host "`n=== Some database connections failed! ===" -ForegroundColor Red
        Write-Host 'Please check database connectivity and credentials before proceeding with installation.' -ForegroundColor Yellow
        return 1
    }
}

# Main execution block
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Write-Host '=== Database Credentials Test - Unified Config System ===' -ForegroundColor Magenta
        
        Write-Host 'Loading configuration...' -ForegroundColor Yellow
        $Config = Get-Config
        Write-Host 'Configuration loaded successfully' -ForegroundColor Green
        Write-Host "Application: $($Config.application)" -ForegroundColor Gray
        Write-Host "Environment: $($Config.EnvironmentName)" -ForegroundColor Gray
        Write-Host "Machine Name: $($Config.Name)" -ForegroundColor Gray
        if ($Config.ContainsKey('ConfigKey')) {
            Write-Host "Config Key: $($Config.ConfigKey)" -ForegroundColor Gray
        }
        if ($Config.ContainsKey('ClusterName')) {
            Write-Host "Cluster: $($Config.ClusterName)" -ForegroundColor Gray
        }
        
        # Test database credentials
        Write-Host 'Starting database credentials test...' -ForegroundColor Yellow
        $exitCode = Test-DbCredentials -Config $Config
        
        if ($exitCode -eq 0) {
            Write-Host 'Database credentials test completed successfully!' -ForegroundColor Green
        }
        else {
            Write-Host 'Database credentials test failed!' -ForegroundColor Red
            exit $exitCode
        }
    }
    catch {
        Write-Error "Failed to execute Test-DbCredentials: $_"
        Write-Error "Stack Trace: $($_.ScriptStackTrace)"
        $global:LASTEXITCODE = 1
        exit 1
    }
}