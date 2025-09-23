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

    # Check database credentials BEFORE installer runs
    $typePath = "$($Config.ORACLE_19C_HOME)\ODP.NET\bin\4\Oracle.DataAccess.dll"

    # Verify Oracle client DLL exists
    if (-not (Test-Path $typePath)) {
        Write-Error "Oracle Data Access DLL not found at: $typePath"
        Write-Error "Please ensure Oracle Client is installed at: $($Config.ORACLE_19C_HOME)"
        return 1
    }

    Write-Host "Using Oracle client DLL: $typePath" -ForegroundColor Gray

    # Get database credentials using unified system
    try {
        Write-Host 'Retrieving database credentials from unified config...' -ForegroundColor Yellow
        
        # Get system database password
        $sysDbPassword = Get-SecretValueUnified -Config $Config -SecretType 'sys_db' -SecretKey $Config.DatabaseConfig.sysDbUser -TestMode:$TestMode
        if (-not $sysDbPassword) {
            Write-Error "Failed to retrieve system database password for user: $($Config.DatabaseConfig.sysDbUser)"
            return 1
        }

        # Get audit database password
        $audDbPassword = Get-SecretValueUnified -Config $Config -SecretType 'aud_db' -SecretKey $Config.DatabaseConfig.audDbUser -TestMode:$TestMode
        if (-not $audDbPassword) {
            Write-Error "Failed to retrieve audit database password for user: $($Config.DatabaseConfig.audDbUser)"
            return 1
        }

        Write-Host 'Successfully retrieved credentials from secrets manager' -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to retrieve database credentials: $_"
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
        
        $Config = Get-Config
        Write-Host 'Configuration loaded successfully' -ForegroundColor Green
        Write-Host "Application: $($Config.application)" -ForegroundColor Gray
        Write-Host "Environment: $($Config.EnvironmentName)" -ForegroundColor Gray
        
        # Test database credentials
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
        exit 1
    }
}