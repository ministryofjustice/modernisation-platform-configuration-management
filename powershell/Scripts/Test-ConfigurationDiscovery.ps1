# Configuration Discovery and Validation Framework
# This script discovers and validates actual configuration values without relying on hardcoded test cases

param (
    [Parameter()]
    [string]$Application,
    
    [Parameter()]
    [string]$EnvironmentName,
    
    [Parameter()]
    [string]$NodeName,
    
    [Parameter()]
    [switch]$TestSecrets,
    
    [Parameter()]
    [switch]$ShowAllConfig,
    
    [Parameter()]
    [switch]$ValidateOnly,
    
    [Parameter()]
    [switch]$UseRealSecrets,
    
    [Parameter()]
    [switch]$TestMode,
    
    [Parameter()]
    [string]$DbEnv,
    
    [Parameter()]
    [string]$OutputDirectory = './ConfigDiscovery'
)

. (Join-Path $PSScriptRoot '..\Configs\unified_config_system.ps1')

# Import the same Get-SecretValue function that the installer scripts use
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
            Write-Warning "The SecretId '$SecretId' does not exist or returned no value."
            return $null
        }

        $secretObject = $secretJson | ConvertFrom-Json

        if (-not $secretObject.PSObject.Properties.Name -contains $SecretKey) {
            Write-Warning "The SecretKey '$SecretKey' does not exist in the secret."
            return $null
        }

        return $secretObject.$SecretKey
    }
    catch {
        Write-Warning "An error occurred while retrieving the secret: $_"
        return $null
    }
}

function Test-ConfigurationDiscovery {
    param(
        [Parameter()]
        [string]$Application,
        
        [Parameter()]
        [string]$Environment,
        
        [Parameter()]
        [string]$NodeName,
        
        [Parameter()]
        [switch]$TestSecrets,
        
        [Parameter()]
        [switch]$ShowAllConfig,
        
        [Parameter()]
        [switch]$ValidateOnly,
        
        [Parameter()]
        [switch]$UseRealSecrets,
        
        [Parameter()]
        [switch]$TestMode,
        
        [Parameter()]
        [string]$DbEnv,
        
        [Parameter()]
        [string]$OutputDirectory = './ConfigDiscovery'
    )

    Write-Host '=== Configuration Discovery Framework ===' -ForegroundColor Green
    Write-Host "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
    Write-Host ''

    # Interactive mode if parameters missing
    if (-not $Application) {
        Write-Host 'Available applications:' -ForegroundColor Yellow
        Write-Host '  - oasys-national-reporting' -ForegroundColor Gray
        Write-Host '  - nomis-combined-reporting' -ForegroundColor Gray
        Write-Host '  - delius-mis' -ForegroundColor Gray
        $Application = Read-Host 'Enter application'
    }

    if (-not $Environment) {
        $Environment = Read-Host 'Enter environment name (e.g., delius-mis-development)'
    }

    if (-not $NodeName) {
        $NodeName = Read-Host 'Enter node name (e.g., delius-mis-dev-dfi-1)'
    }

    # Create output directory
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    Write-Host 'Testing Configuration for:' -ForegroundColor Cyan
    Write-Host "  Application: $Application" -ForegroundColor White
    Write-Host "  Environment: $Environment" -ForegroundColor White
    Write-Host "  Node Name: $NodeName" -ForegroundColor White
    Write-Host ''

    try {
        # Step 1: Load Configuration
        Write-Host '1. Loading Configuration...' -ForegroundColor Cyan
        
        $additionalTags = @{
            application = $Application
            Name        = $NodeName
            domainName  = "$Application.local"  # Generic domain for testing
        }
        
        $config = Get-UnifiedConfig -EnvironmentName $Environment -Application $Application -AdditionalTags $additionalTags
        Write-Host '   ✓ Configuration loaded successfully' -ForegroundColor Green
        
        # Step 1.5: Determine or set dbenv for NCR/ONR environments
        if ($Application -eq 'nomis-combined-reporting' -or $Application -eq 'oasys-national-reporting') {
            if ($DbEnv) {
                # Use provided DbEnv parameter (allows full flexibility)
                $config.dbenv = $DbEnv
                Write-Host "   ✓ Using provided dbenv: $DbEnv" -ForegroundColor Green
            }
            elseif ([string]::IsNullOrEmpty($config.dbenv)) {
                # Auto-determine dbenv based on environment using standard naming conventions
                # Use more specific regex to avoid 'preproduction' matching 'production'
                $inferredDbEnv = switch -Regex ($Environment) {
                    'preproduction' { 'pp' }      # Check preproduction FIRST before production
                    '^.*-production$' { 'pd' }    # Only match if it ends with -production (not preproduction)
                    'development' { 'dev' }
                    'test' { 
                        # Test environments are complex - could be t1, t2, etc.
                        # Extract the specific test environment from node name if possible
                        if ($NodeName -match 't(\d+)-') {
                            "t$($matches[1])"  # e.g., t2-onr-bods-1 -> t2
                        }
                        else {
                            Write-Warning "Test environment detected but cannot determine specific test instance (t1, t2, etc.)"
                            Write-Warning "Please use -DbEnv parameter to specify (e.g., -DbEnv 't1' or -DbEnv 't2')"
                            'test-unknown'
                        }
                    }
                    default { 
                        Write-Warning "Cannot auto-determine dbenv for environment: $Environment"
                        Write-Warning "Please use -DbEnv parameter to specify the correct value"
                        'unknown'
                    }
                }
                $config.dbenv = $inferredDbEnv
                
                if ($inferredDbEnv -notlike '*unknown*') {
                    Write-Host "   ✓ Auto-determined dbenv: $inferredDbEnv" -ForegroundColor Yellow
                    Write-Host "     (Standard naming: dev/pp/pd/t1/t2/etc.)" -ForegroundColor Gray
                }
                else {
                    Write-Host "   ⚠️ Could not determine dbenv: $inferredDbEnv" -ForegroundColor Yellow
                    Write-Host "     Use -DbEnv parameter to specify correct value" -ForegroundColor Gray
                }
                Write-Host "     (You can always override with -DbEnv parameter)" -ForegroundColor Gray
            }
            else {
                Write-Host "   ✓ Using existing dbenv from config: $($config.dbenv)" -ForegroundColor Green
            }
        }

        # Step 2: Analyze Configuration Structure
        Write-Host "`n2. Configuration Analysis..." -ForegroundColor Cyan
        
        $configAnalysis = @{
            CoreProperties    = @()
            DatabaseConfig    = @()
            NodeConfig        = @()
            ServiceConfig     = @()
            SecretConfig      = @()
            PathConfig        = @()
            ClusterInfo       = @()
            UnknownProperties = @()
        }

        # Analyze all properties
        foreach ($property in $config.PSObject.Properties) {
            $name = $property.Name
            $value = $property.Value
            $valueType = if ($null -ne $value) { $value.GetType().Name } else { 'null' }
            
            $propertyInfo = @{
                Name    = $name
                Value   = $value
                Type    = $valueType
                IsEmpty = [string]::IsNullOrEmpty($value)
            }

            # Categorize properties
            switch -Regex ($name) {
                '^(application|environment|ConfigKey|DetectedRole|ClusterName)$' {
                    $configAnalysis.CoreProperties += $propertyInfo
                }
                '^Database|.*Db.*|.*Database.*' {
                    $configAnalysis.DatabaseConfig += $propertyInfo
                }
                '^Node|.*Node.*|cms.*Node.*' {
                    $configAnalysis.NodeConfig += $propertyInfo
                }
                '^Service|.*Service.*|.*User.*' {
                    $configAnalysis.ServiceConfig += $propertyInfo
                }
                '^Secret|.*Secret.*|.*Pattern.*' {
                    $configAnalysis.SecretConfig += $propertyInfo
                }
                '^.*Directory|.*HOME|.*Path|.*DIR.*' {
                    $configAnalysis.PathConfig += $propertyInfo
                }
                '^Cluster|Primary|Secondary' {
                    $configAnalysis.ClusterInfo += $propertyInfo
                }
                default {
                    $configAnalysis.UnknownProperties += $propertyInfo
                }
            }
        }

        # Display analysis results
        foreach ($category in $configAnalysis.Keys | Sort-Object) {
            $properties = $configAnalysis[$category]
            if ($properties.Count -gt 0) {
                Write-Host "   $category ($($properties.Count) properties):" -ForegroundColor Yellow
                foreach ($prop in $properties | Sort-Object Name) {
                    $status = if ($prop.IsEmpty) { '⚠️' } else { '✓' }
                    $displayValue = if ($prop.Value -is [PSCustomObject]) { 
                        "[Object with $($prop.Value.PSObject.Properties.Count) properties]" 
                    }
                    elseif ([string]::IsNullOrEmpty($prop.Value)) {
                        '[EMPTY]'
                    }
                    else { 
                        $prop.Value 
                    }
                    Write-Host "     $status $($prop.Name): $displayValue" -ForegroundColor Gray
                }
                Write-Host ''
            }
        }

        # Step 3: Validate Critical Configuration
        Write-Host '3. Configuration Validation...' -ForegroundColor Cyan
        
        $validationResults = @{
            Critical = @()
            Warnings = @()
            Info     = @()
        }

        # Critical validations
        $criticalChecks = @(
            @{ Name = 'Application'; Value = $config.application; Required = $true },
            @{ Name = 'Environment'; Value = $config.environment; Required = $true },
            @{ Name = 'Config Key'; Value = $config.ConfigKey; Required = $true },
            @{ Name = 'Detected Role'; Value = $config.DetectedRole; Required = $true }
        )

        foreach ($check in $criticalChecks) {
            if ([string]::IsNullOrEmpty($check.Value)) {
                $validationResults.Critical += "❌ $($check.Name) is missing or empty"
            }
            else {
                $validationResults.Info += "✅ $($check.Name): $($check.Value)"
            }
        }

        # Database validation
        if ($null -ne $config.DatabaseConfig) {
            if (($null -ne $config.DatabaseConfig.sysDbName) -and ($null -ne $config.DatabaseConfig.audDbName)) {
                $validationResults.Info += '✅ Database configuration complete'
                $validationResults.Info += "   - System DB: $($config.DatabaseConfig.sysDbName)"
                $validationResults.Info += "   - Audit DB: $($config.DatabaseConfig.audDbName)"
            }
            else {
                $validationResults.Warnings += '⚠️ Database configuration incomplete'
            }
        }
        else {
            $validationResults.Warnings += '⚠️ No database configuration found'
        }

        # Cluster validation
        if ($config.DetectedRole -eq 'primary' -or $config.DetectedRole -eq 'secondary') {
            if (($null -ne $config.NodeConfig.cmsPrimaryNode) -and ($null -ne $config.NodeConfig.cmsSecondaryNode)) {
                $validationResults.Info += '✅ Cluster pairing configured'
                $validationResults.Info += "   - Primary: $($config.NodeConfig.cmsPrimaryNode)"
                $validationResults.Info += "   - Secondary: $($config.NodeConfig.cmsSecondaryNode)"
            }
            else {
                $validationResults.Critical += '❌ Cluster role detected but pairing incomplete'
            }
        }

        # Path validation
        $pathChecks = @(
            @{ Name = 'Working Directory'; Value = $config.WorkingDirectory },
            @{ Name = 'Oracle Home'; Value = $config.ORACLE_19C_HOME },
            @{ Name = 'BIP Install Dir'; Value = $config.BIP_INSTALL_DIR }
        )

        foreach ($pathCheck in $pathChecks) {
            if ([string]::IsNullOrEmpty($pathCheck.Value)) {
                $validationResults.Warnings += "⚠️ $($pathCheck.Name) not configured"
            }
            else {
                $validationResults.Info += "✅ $($pathCheck.Name): $($pathCheck.Value)"
            }
        }

        # Display validation results
        foreach ($level in @('Critical', 'Warnings', 'Info')) {
            $results = $validationResults[$level]
            if ($results.Count -gt 0) {
                $color = switch ($level) {
                    'Critical' { 'Red' }
                    'Warnings' { 'Yellow' }
                    'Info' { 'Green' }
                }
                Write-Host "   $level Issues:" -ForegroundColor $color
                foreach ($result in $results) {
                    Write-Host "   $result" -ForegroundColor Gray
                }
                Write-Host ''
            }
        }

        # Step 4: Secret Testing (if requested) - Mimic Install-IPS and Install-DataServices logic
        if ($TestSecrets) {
            Write-Host '4. Secret Configuration Testing (Mimicking Installer Scripts)...' -ForegroundColor Cyan
            
            # Use the EXACT same logic as Install-IPS.ps1 and Install-DataServices.ps1
            Write-Host '   Testing secrets using installer script logic...' -ForegroundColor Yellow
            
            $secretResults = @()
            
            try {
                # Determine secret ID and keys based on configuration structure (same as installer scripts)
                if ($config.SecretConfig.ContainsKey('secretIds') -and $config.SecretConfig.ContainsKey('secretKeys')) {
                    # MISDis-style explicit configuration
                    Write-Host '   Using MISDis-style explicit secret configuration' -ForegroundColor Cyan
                    $bodsSecretId = $config.SecretConfig.secretIds.serviceAccounts
                    $bodsAdminPasswordKey = $config.SecretConfig.secretKeys.bodsAdminPassword
                    $serviceUserPasswordKey = $config.SecretConfig.secretKeys.serviceUserPassword
                    $sysDbSecretId = $config.SecretConfig.secretIds.sysDbSecrets
                    $audDbSecretId = $config.SecretConfig.secretIds.audDbSecrets
                    $sysDbPasswordKey = $config.SecretConfig.secretKeys.sysDbUserPassword
                    $audDbPasswordKey = $config.SecretConfig.secretKeys.audDbUserPassword
                    
                    Write-Host "   BODS Secret ID: $bodsSecretId" -ForegroundColor Gray
                    Write-Host "   BODS Admin Key: $bodsAdminPasswordKey" -ForegroundColor Gray
                    Write-Host "   Service User Key: $serviceUserPasswordKey" -ForegroundColor Gray
                    Write-Host "   System DB Secret ID: $sysDbSecretId" -ForegroundColor Gray
                    Write-Host "   System DB Key: $sysDbPasswordKey" -ForegroundColor Gray
                    Write-Host "   Audit DB Secret ID: $audDbSecretId" -ForegroundColor Gray
                    Write-Host "   Audit DB Key: $audDbPasswordKey" -ForegroundColor Gray
                }
                else {
                    # NCR/ONR-style pattern-based configuration with sensible defaults
                    Write-Host '   Using NCR/ONR-style pattern-based secret configuration' -ForegroundColor Cyan
                    $bodsSecretId = $config.SecretConfig.secretMappings.bodsSecretName -replace '\{dbenv\}', $config.dbenv
                    $bodsAdminPasswordKey = 'bods_admin_password'  # Standard key name
                    
                    # For NCR/ONR, use standard service user key pattern or derive from config
                    if ($config.SecretConfig.ContainsKey('secretKeys') -and $config.SecretConfig.secretKeys.ContainsKey('serviceUserPassword')) {
                        $serviceUserPasswordKey = $config.SecretConfig.secretKeys.serviceUserPassword
                    } else {
                        $serviceUserPasswordKey = 'svc_nart'  # Standard fallback for NCR/ONR
                    }
                    
                    # Handle database configuration
                    if ([string]::IsNullOrEmpty($config.DatabaseConfig.sysDbName) -or [string]::IsNullOrEmpty($config.DatabaseConfig.audDbName)) {
                        Write-Host "   ⚠️ Database names not configured - skipping database secret tests" -ForegroundColor Yellow
                        Write-Host "     sysDbName: '$($config.DatabaseConfig.sysDbName)'" -ForegroundColor Gray
                        Write-Host "     audDbName: '$($config.DatabaseConfig.audDbName)'" -ForegroundColor Gray
                        Write-Host "     Database secrets will need to be configured in the config files" -ForegroundColor Gray
                        $sysDbSecretId = 'NOT_CONFIGURED'
                        $audDbSecretId = 'NOT_CONFIGURED'
                        $sysDbPasswordKey = 'NOT_CONFIGURED'
                        $audDbPasswordKey = 'NOT_CONFIGURED'
                    }
                    else {
                        $sysDbSecretId = $config.SecretConfig.secretMappings.sysDbSecretName -replace '\{sysDbName\}', $config.DatabaseConfig.sysDbName
                        $audDbSecretId = $config.SecretConfig.secretMappings.audDbSecretName -replace '\{audDbName\}', $config.DatabaseConfig.audDbName
                        
                        # Use explicit secret keys if defined, otherwise use standard IPS key names
                        if ($config.SecretConfig.ContainsKey('secretKeys') -and $config.SecretConfig.secretKeys.ContainsKey('sysDbUserPassword')) {
                            $sysDbPasswordKey = $config.SecretConfig.secretKeys.sysDbUserPassword
                        } else {
                            $sysDbPasswordKey = 'bods_ips_system_owner'  # Standard IPS system DB key
                        }
                        
                        if ($config.SecretConfig.ContainsKey('secretKeys') -and $config.SecretConfig.secretKeys.ContainsKey('audDbUserPassword')) {
                            $audDbPasswordKey = $config.SecretConfig.secretKeys.audDbUserPassword
                        } else {
                            $audDbPasswordKey = 'bods_ips_audit_owner'  # Standard IPS audit DB key
                        }
                    }
                    
                    Write-Host "   BODS Secret ID (pattern): $bodsSecretId" -ForegroundColor Gray
                    Write-Host "   BODS Admin Key (standard): $bodsAdminPasswordKey" -ForegroundColor Gray
                    Write-Host "   Service User Key: $serviceUserPasswordKey" -ForegroundColor Gray
                    Write-Host "   System DB Secret ID (pattern): $sysDbSecretId" -ForegroundColor Gray
                    Write-Host "   System DB Key: $sysDbPasswordKey" -ForegroundColor Gray
                    Write-Host "   Audit DB Secret ID (pattern): $audDbSecretId" -ForegroundColor Gray
                    Write-Host "   Audit DB Key: $audDbPasswordKey" -ForegroundColor Gray
                }
                
                # Test the exact secrets that Install-IPS.ps1 needs
                Write-Host "`n   Testing Install-IPS.ps1 secrets:" -ForegroundColor Cyan
                
                # Test BODS Admin Password (needed for both primary and secondary IPS)
                try {
                    $bods_cluster_key = if ($UseRealSecrets -and -not $TestMode) {
                        Get-SecretValue -SecretId $bodsSecretId -SecretKey $bodsAdminPasswordKey
                    }
                    else {
                        "TEST_VALUE_$bodsAdminPasswordKey"
                    }
                    
                    if ($null -eq $bods_cluster_key -or $bods_cluster_key -eq '') {
                        $secretResults += @{
                            Script      = 'Install-IPS.ps1'
                            Description = 'BODS Cluster Key (IPS Admin Password)'
                            SecretId    = $bodsSecretId
                            SecretKey   = $bodsAdminPasswordKey
                            Status      = 'FAILED'
                            Value       = $null
                            Error       = 'Secret not found or returned empty value'
                        }
                        Write-Host '   ❌ BODS Cluster Key: Secret not found or empty' -ForegroundColor Red
                    }
                    else {
                        $secretResults += @{
                            Script      = 'Install-IPS.ps1'
                            Description = 'BODS Cluster Key (IPS Admin Password)'
                            SecretId    = $bodsSecretId
                            SecretKey   = $bodsAdminPasswordKey
                            Status      = 'SUCCESS'
                            Value       = if ($bods_cluster_key.Length -gt 10) { "$($bods_cluster_key.Substring(0,10))..." } else { $bods_cluster_key }
                            Error       = $null
                        }
                        Write-Host '   ✅ BODS Cluster Key: Retrieved successfully' -ForegroundColor Green
                    }
                }
                catch {
                    $secretResults += @{
                        Script      = 'Install-IPS.ps1'
                        Description = 'BODS Cluster Key (IPS Admin Password)'
                        SecretId    = $bodsSecretId
                        SecretKey   = $bodsAdminPasswordKey
                        Status      = 'ERROR'
                        Value       = $null
                        Error       = $_.Exception.Message
                    }
                    Write-Host "   ❌ BODS Cluster Key: $($_.Exception.Message)" -ForegroundColor Red
                }
                
                # Test System DB Password (needed for IPS primary and secondary)
                if ($sysDbSecretId -eq 'NOT_CONFIGURED') {
                    $secretResults += @{
                        Script = 'Install-IPS.ps1'
                        Description = 'System DB User Password'
                        SecretId = 'NOT_CONFIGURED'
                        SecretKey = 'NOT_CONFIGURED'
                        Status = 'SKIPPED'
                        Value = $null
                        Error = 'Database configuration missing - sysDbName not configured'
                    }
                    Write-Host "   ⚠️ System DB Password: Skipped (database not configured)" -ForegroundColor Yellow
                }
                else {
                    try {
                        $bods_ips_system_owner = if ($UseRealSecrets -and -not $TestMode) {
                            Get-SecretValue -SecretId $sysDbSecretId -SecretKey $sysDbPasswordKey
                        }
                        else {
                            "TEST_VALUE_$sysDbPasswordKey"
                        }
                    
                    if ($null -eq $bods_ips_system_owner -or $bods_ips_system_owner -eq '') {
                        $secretResults += @{
                            Script      = 'Install-IPS.ps1'
                            Description = 'System DB User Password'
                            SecretId    = $sysDbSecretId
                            SecretKey   = $sysDbPasswordKey
                            Status      = 'FAILED'
                            Value       = $null
                            Error       = 'Secret not found or returned empty value'
                        }
                        Write-Host '   ❌ System DB Password: Secret not found or empty' -ForegroundColor Red
                    }
                    else {
                        $secretResults += @{
                            Script      = 'Install-IPS.ps1'
                            Description = 'System DB User Password'
                            SecretId    = $sysDbSecretId
                            SecretKey   = $sysDbPasswordKey
                            Status      = 'SUCCESS'
                            Value       = if ($bods_ips_system_owner.Length -gt 10) { "$($bods_ips_system_owner.Substring(0,10))..." } else { $bods_ips_system_owner }
                            Error       = $null
                        }
                        Write-Host '   ✅ System DB Password: Retrieved successfully' -ForegroundColor Green
                    }
                    }
                    catch {
                        $secretResults += @{
                            Script      = 'Install-IPS.ps1'
                            Description = 'System DB User Password'
                            SecretId    = $sysDbSecretId
                            SecretKey   = $sysDbPasswordKey
                            Status      = 'ERROR'
                            Value       = $null
                            Error       = $_.Exception.Message
                        }
                        Write-Host "   ❌ System DB Password: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                
                # Test Audit DB Password (needed for IPS primary only)
                if ($audDbSecretId -eq 'NOT_CONFIGURED') {
                    $secretResults += @{
                        Script = 'Install-IPS.ps1 (Primary only)'
                        Description = 'Audit DB User Password'
                        SecretId = 'NOT_CONFIGURED'
                        SecretKey = 'NOT_CONFIGURED'
                        Status = 'SKIPPED'
                        Value = $null
                        Error = 'Database configuration missing - audDbName not configured'
                    }
                    Write-Host "   ⚠️ Audit DB Password: Skipped (database not configured)" -ForegroundColor Yellow
                }
                else {
                    try {
                        $bods_ips_audit_owner = if ($UseRealSecrets -and -not $TestMode) {
                            Get-SecretValue -SecretId $audDbSecretId -SecretKey $audDbPasswordKey
                        }
                        else {
                        "TEST_VALUE_$audDbPasswordKey"
                    }
                    
                    if ($null -eq $bods_ips_audit_owner -or $bods_ips_audit_owner -eq '') {
                        $secretResults += @{
                            Script      = 'Install-IPS.ps1 (Primary only)'
                            Description = 'Audit DB User Password'
                            SecretId    = $audDbSecretId
                            SecretKey   = $audDbPasswordKey
                            Status      = 'FAILED'
                            Value       = $null
                            Error       = 'Secret not found or returned empty value'
                        }
                        Write-Host '   ❌ Audit DB Password: Secret not found or empty' -ForegroundColor Red
                    }
                    else {
                        $secretResults += @{
                            Script      = 'Install-IPS.ps1 (Primary only)'
                            Description = 'Audit DB User Password'
                            SecretId    = $audDbSecretId
                            SecretKey   = $audDbPasswordKey
                            Status      = 'SUCCESS'
                            Value       = if ($bods_ips_audit_owner.Length -gt 10) { "$($bods_ips_audit_owner.Substring(0,10))..." } else { $bods_ips_audit_owner }
                            Error       = $null
                        }
                        Write-Host '   ✅ Audit DB Password: Retrieved successfully' -ForegroundColor Green
                    }
                    }
                    catch {
                        $secretResults += @{
                            Script      = 'Install-IPS.ps1 (Primary only)'
                            Description = 'Audit DB User Password'
                            SecretId    = $audDbSecretId
                            SecretKey   = $audDbPasswordKey
                            Status      = 'ERROR'
                            Value       = $null
                            Error       = $_.Exception.Message
                        }
                        Write-Host "   ❌ Audit DB Password: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }
                
                # Test SQL Anywhere Admin Password (needed for MISDis 4.3 installations only)
                if ($config.application -eq 'delius-mis') {
                    Write-Host "`n   Testing SQL Anywhere password (MISDis 4.3 only):" -ForegroundColor Cyan
                    
                    # Check if sqlAnywhereAdminPassword key exists in config
                    if ($config.SecretConfig.ContainsKey('secretKeys') -and $config.SecretConfig.secretKeys.ContainsKey('sqlAnywhereAdminPassword')) {
                        $sqlAnywherePasswordKey = $config.SecretConfig.secretKeys.sqlAnywhereAdminPassword
                        
                        try {
                            $sqlAnywherePassword = if ($UseRealSecrets -and -not $TestMode) {
                                Get-SecretValue -SecretId $bodsSecretId -SecretKey $sqlAnywherePasswordKey
                            }
                            else {
                                "TEST_VALUE_$sqlAnywherePasswordKey"
                            }
                            
                            if ($null -eq $sqlAnywherePassword -or $sqlAnywherePassword -eq '') {
                                $secretResults += @{
                                    Script      = 'Install-IPS.ps1 (MISDis 4.3 only)'
                                    Description = 'SQL Anywhere Admin Password'
                                    SecretId    = $bodsSecretId
                                    SecretKey   = $sqlAnywherePasswordKey
                                    Status      = 'FAILED'
                                    Value       = $null
                                    Error       = 'Secret not found or returned empty value'
                                }
                                Write-Host '   ❌ SQL Anywhere Password: Secret not found or empty' -ForegroundColor Red
                            }
                            else {
                                $secretResults += @{
                                    Script      = 'Install-IPS.ps1 (MISDis 4.3 only)'
                                    Description = 'SQL Anywhere Admin Password'
                                    SecretId    = $bodsSecretId
                                    SecretKey   = $sqlAnywherePasswordKey
                                    Status      = 'SUCCESS'
                                    Value       = if ($sqlAnywherePassword.Length -gt 10) { "$($sqlAnywherePassword.Substring(0,10))..." } else { $sqlAnywherePassword }
                                    Error       = $null
                                }
                                Write-Host '   ✅ SQL Anywhere Password: Retrieved successfully' -ForegroundColor Green
                            }
                        }
                        catch {
                            $secretResults += @{
                                Script      = 'Install-IPS.ps1 (MISDis 4.3 only)'
                                Description = 'SQL Anywhere Admin Password'
                                SecretId    = $bodsSecretId
                                SecretKey   = $sqlAnywherePasswordKey
                                Status      = 'ERROR'
                                Value       = $null
                                Error       = $_.Exception.Message
                            }
                            Write-Host "   ❌ SQL Anywhere Password: $($_.Exception.Message)" -ForegroundColor Red
                        }
                    }
                    else {
                        $secretResults += @{
                            Script      = 'Install-IPS.ps1 (MISDis 4.3 only)'
                            Description = 'SQL Anywhere Admin Password'
                            SecretId    = 'N/A'
                            SecretKey   = 'NOT_CONFIGURED'
                            Status      = 'SKIPPED'
                            Value       = $null
                            Error       = 'sqlAnywhereAdminPassword not configured in secretKeys - will fail for 4.3 installs'
                        }
                        Write-Host '   ⚠️ SQL Anywhere Password: Not configured in secretKeys (required for 4.3)' -ForegroundColor Yellow
                    }
                }
                else {
                    Write-Host "`n   SQL Anywhere password test skipped (not MISDis)" -ForegroundColor Gray
                }
                
                # Test the exact secrets that Install-DataServices.ps1 needs
                Write-Host "`n   Testing Install-DataServices.ps1 secrets:" -ForegroundColor Cyan
                
                # Test BODS Admin Password (same as IPS)
                $secretResults += @{
                    Script      = 'Install-DataServices.ps1'
                    Description = 'BODS Admin Password (same as IPS)'
                    SecretId    = $bodsSecretId
                    SecretKey   = $bodsAdminPasswordKey
                    Status      = $secretResults | Where-Object { $_.Description -eq 'BODS Cluster Key (IPS Admin Password)' } | Select-Object -ExpandProperty Status
                    Value       = $secretResults | Where-Object { $_.Description -eq 'BODS Cluster Key (IPS Admin Password)' } | Select-Object -ExpandProperty Value
                    Error       = $secretResults | Where-Object { $_.Description -eq 'BODS Cluster Key (IPS Admin Password)' } | Select-Object -ExpandProperty Error
                }
                Write-Host '   ℹ️ BODS Admin Password: Same as IPS cluster key (already tested)' -ForegroundColor Cyan
                
                # Test Service User Password
                try {
                    $service_user_password = if ($UseRealSecrets -and -not $TestMode) {
                        Get-SecretValue -SecretId $bodsSecretId -SecretKey $serviceUserPasswordKey
                    }
                    else {
                        "TEST_VALUE_$serviceUserPasswordKey"
                    }
                    
                    if ($null -eq $service_user_password -or $service_user_password -eq '') {
                        $secretResults += @{
                            Script      = 'Install-DataServices.ps1'
                            Description = 'Service User Password'
                            SecretId    = $bodsSecretId
                            SecretKey   = $serviceUserPasswordKey
                            Status      = 'FAILED'
                            Value       = $null
                            Error       = 'Secret not found or returned empty value'
                        }
                        Write-Host '   ❌ Service User Password: Secret not found or empty' -ForegroundColor Red
                    }
                    else {
                        $secretResults += @{
                            Script      = 'Install-DataServices.ps1'
                            Description = 'Service User Password'
                            SecretId    = $bodsSecretId
                            SecretKey   = $serviceUserPasswordKey
                            Status      = 'SUCCESS'
                            Value       = if ($service_user_password.Length -gt 10) { "$($service_user_password.Substring(0,10))..." } else { $service_user_password }
                            Error       = $null
                        }
                        Write-Host '   ✅ Service User Password: Retrieved successfully' -ForegroundColor Green
                    }
                }
                catch {
                    $secretResults += @{
                        Script      = 'Install-DataServices.ps1'
                        Description = 'Service User Password'
                        SecretId    = $bodsSecretId
                        SecretKey   = $serviceUserPasswordKey
                        Status      = 'ERROR'
                        Value       = $null
                        Error       = $_.Exception.Message
                    }
                    Write-Host "   ❌ Service User Password: $($_.Exception.Message)" -ForegroundColor Red
                }
                
            }
            catch {
                Write-Host "   ❌ Failed to test secrets: $($_.Exception.Message)" -ForegroundColor Red
                $secretResults += @{
                    Script      = 'Secret Testing Framework'
                    Description = 'General Error'
                    SecretId    = 'N/A'
                    SecretKey   = 'N/A'
                    Status      = 'ERROR'
                    Value       = $null
                    Error       = $_.Exception.Message
                }
            }
            
            # Summary
            $successCount = ($secretResults | Where-Object { $_.Status -eq 'SUCCESS' }).Count
            $failedCount = ($secretResults | Where-Object { $_.Status -eq 'FAILED' }).Count
            $errorCount = ($secretResults | Where-Object { $_.Status -eq 'ERROR' }).Count
            $skippedCount = ($secretResults | Where-Object { $_.Status -eq 'SKIPPED' }).Count
            
            Write-Host "`n   Secret Test Summary:" -ForegroundColor Yellow
            Write-Host "   ✅ Success: $successCount" -ForegroundColor Green
            Write-Host "   ❌ Failed: $failedCount" -ForegroundColor Red
            Write-Host "   ⚠️ Errors: $errorCount" -ForegroundColor Yellow
            Write-Host "   ⏭️ Skipped: $skippedCount" -ForegroundColor Cyan
            
            if ($failedCount -gt 0 -or $errorCount -gt 0) {
                Write-Host "`n   ⚠️ WARNING: Some secrets failed. The installer scripts may fail!" -ForegroundColor Yellow
            }
            else {
                Write-Host "`n   ✅ All secrets retrieved successfully. Installers should work!" -ForegroundColor Green
            }
            
            # Save secret test results
            $secretOutputFile = Join-Path $OutputDirectory "installer-secret-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            $secretResults | ConvertTo-Json -Depth 5 | Out-File $secretOutputFile
            Write-Host "   Secret test results saved to: $secretOutputFile" -ForegroundColor Gray
        }

        # Step 5: Generate Complete Configuration Report
        if ($ShowAllConfig -and -not $ValidateOnly) {
            Write-Host '5. Generating Complete Configuration Report...' -ForegroundColor Cyan
            
            $reportData = @{
                Timestamp      = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                TestParameters = @{
                    Application = $Application
                    Environment = $Environment
                    NodeName    = $NodeName
                }
                Configuration  = $config
                Analysis       = $configAnalysis
                Validation     = $validationResults
            }
            
            if ($TestSecrets) {
                $reportData.SecretTests = $secretResults
            }
            
            $reportFile = Join-Path $OutputDirectory "config-report-$Application-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
            $reportData | ConvertTo-Json -Depth 10 | Out-File $reportFile
            Write-Host "   ✅ Complete report saved to: $reportFile" -ForegroundColor Green
            
            # Generate human-readable summary
            $summaryFile = Join-Path $OutputDirectory "config-summary-$Application-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
            $summary = @"
Configuration Discovery Report
=============================
Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

Test Parameters:
- Application: $Application
- Environment: $Environment  
- Node Name: $NodeName

Configuration Summary:
- Config Key: $($config.ConfigKey)
- Detected Role: $($config.DetectedRole)
- Cluster Name: $($config.ClusterName)
- Application Directory: $($config.AppDirectory)
- Working Directory: $($config.WorkingDirectory)

Database Configuration:
- System DB: $($config.DatabaseConfig.sysDbName)
- Audit DB: $($config.DatabaseConfig.audDbName)

Node Configuration:
- Primary Node: $($config.NodeConfig.cmsPrimaryNode)
- Secondary Node: $($config.NodeConfig.cmsSecondaryNode)

Critical Paths:
- Oracle Home: $($config.ORACLE_19C_HOME)
- BIP Install Dir: $($config.BIP_INSTALL_DIR)

Service Configuration:
- Service User: $($config.ServiceConfig.serviceUser)
- Service Group: $($config.ServiceConfig.serviceGroup)

Validation Summary:
- Critical Issues: $($validationResults.Critical.Count)
- Warnings: $($validationResults.Warnings.Count)
- Successful Checks: $($validationResults.Info.Count)

"@
            $summary | Out-File $summaryFile
            Write-Host "   ✅ Human-readable summary saved to: $summaryFile" -ForegroundColor Green
        }

        # Step 6: Final Summary
        Write-Host "`n=== Discovery Complete ===" -ForegroundColor Green
        
        $totalIssues = $validationResults.Critical.Count + $validationResults.Warnings.Count
        if ($totalIssues -eq 0) {
            Write-Host 'Configuration appears healthy! ✅' -ForegroundColor Green
        }
        else {
            Write-Host "Configuration has $totalIssues issues that need attention:" -ForegroundColor Yellow
            Write-Host "  - Critical: $($validationResults.Critical.Count)" -ForegroundColor Red
            Write-Host "  - Warnings: $($validationResults.Warnings.Count)" -ForegroundColor Yellow
        }
        
        Write-Host "Output saved to: $OutputDirectory" -ForegroundColor Gray
        
        return @{
            Config      = $config
            Analysis    = $configAnalysis
            Validation  = $validationResults
            SecretTests = if ($TestSecrets) { $secretResults } else { $null }
        }

    }
    catch {
        Write-Host "`n=== Discovery Failed ===" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Location: $($_.InvocationInfo.ScriptName):$($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
        throw
    }
}

function Compare-NodeConfigurations {
    param(
        [Parameter(Mandatory)]
        [string]$Application,
        
        [Parameter(Mandatory)]
        [string]$Environment,
        
        [Parameter(Mandatory)]
        [string[]]$NodeNames,
        
        [Parameter()]
        [string]$OutputDirectory = './ConfigDiscovery'
    )
    
    Write-Host '=== Comparing Node Configurations ===' -ForegroundColor Green
    Write-Host "Application: $Application" -ForegroundColor Cyan
    Write-Host "Environment: $Environment" -ForegroundColor Cyan
    Write-Host "Nodes: $($NodeNames -join ', ')" -ForegroundColor Cyan
    Write-Host ''
    
    $nodeConfigs = @{}
    $nodeResults = @{}
    
    # Load all configurations
    foreach ($nodeName in $NodeNames) {
        Write-Host "Loading configuration for $nodeName..." -ForegroundColor Yellow
        try {
            $result = Test-ConfigurationDiscovery -Application $Application -Environment $Environment -NodeName $nodeName -ValidateOnly -UseRealSecrets:$UseRealSecrets -TestMode:$TestMode -DbEnv $DbEnv -OutputDirectory $OutputDirectory
            $nodeConfigs[$nodeName] = $result.Config
            $nodeResults[$nodeName] = $result
            Write-Host '  ✅ Loaded successfully' -ForegroundColor Green
        }
        catch {
            Write-Host "  ❌ Failed to load: $($_.Exception.Message)" -ForegroundColor Red
            $nodeResults[$nodeName] = @{ Error = $_.Exception.Message }
        }
    }
    
    # Compare configurations
    Write-Host "`nComparing configurations..." -ForegroundColor Cyan
    
    $comparisonReport = @{
        Timestamp    = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Application  = $Application
        Environment  = $Environment
        NodeNames    = $NodeNames
        Differences  = @()
        Similarities = @()
        Issues       = @()
    }
    
    # Compare each pair of nodes
    for ($i = 0; $i -lt $NodeNames.Count; $i++) {
        for ($j = $i + 1; $j -lt $NodeNames.Count; $j++) {
            $node1 = $NodeNames[$i]
            $node2 = $NodeNames[$j]
            
            if (($null -ne $nodeResults[$node1].Error) -or ($null -ne $nodeResults[$node2].Error)) {
                $comparisonReport.Issues += "Cannot compare $node1 and $node2 due to loading errors"
                continue
            }
            
            Write-Host "  Comparing $node1 vs $node2..." -ForegroundColor Gray
            
            $config1 = $nodeConfigs[$node1]
            $config2 = $nodeConfigs[$node2]
            
            # Compare key properties
            $comparisonProps = @('DetectedRole', 'ClusterName', 'ConfigKey', 'DatabaseConfig', 'NodeConfig')
            
            foreach ($prop in $comparisonProps) {
                $val1 = $config1.$prop
                $val2 = $config2.$prop
                
                if ($prop -eq 'DatabaseConfig' -or $prop -eq 'NodeConfig') {
                    # Compare object properties
                    if ($val1 -and $val2) {
                        foreach ($subProp in $val1.PSObject.Properties.Name) {
                            if ($val1.$subProp -ne $val2.$subProp) {
                                $comparisonReport.Differences += @{
                                    Property = "$prop.$subProp"
                                    Node1    = $node1
                                    Value1   = $val1.$subProp
                                    Node2    = $node2
                                    Value2   = $val2.$subProp
                                }
                            }
                            else {
                                $comparisonReport.Similarities += @{
                                    Property = "$prop.$subProp"
                                    Nodes    = @($node1, $node2)
                                    Value    = $val1.$subProp
                                }
                            }
                        }
                    }
                }
                else {
                    if ($val1 -ne $val2) {
                        $comparisonReport.Differences += @{
                            Property = $prop
                            Node1    = $node1
                            Value1   = $val1
                            Node2    = $node2
                            Value2   = $val2
                        }
                    }
                    else {
                        $comparisonReport.Similarities += @{
                            Property = $prop
                            Nodes    = @($node1, $node2)
                            Value    = $val1
                        }
                    }
                }
            }
        }
    }
    
    # Display results
    if ($comparisonReport.Differences.Count -gt 0) {
        Write-Host "`nDifferences found:" -ForegroundColor Yellow
        foreach ($diff in $comparisonReport.Differences) {
            Write-Host "  $($diff.Property):" -ForegroundColor Red
            Write-Host "    $($diff.Node1): $($diff.Value1)" -ForegroundColor Gray
            Write-Host "    $($diff.Node2): $($diff.Value2)" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "`n✅ No significant differences found between nodes" -ForegroundColor Green
    }
    
    # Save comparison report
    $reportFile = Join-Path $OutputDirectory "node-comparison-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $comparisonReport | ConvertTo-Json -Depth 10 | Out-File $reportFile
    Write-Host "`nComparison report saved to: $reportFile" -ForegroundColor Gray
    
    return $comparisonReport
}

# Script execution logic
if ($MyInvocation.InvocationName -ne '.') {
    # If script is run directly (not dot-sourced)
    if ($Application -or $EnvironmentName -or $NodeName) {
        Test-ConfigurationDiscovery -Application $Application -Environment $EnvironmentName -NodeName $NodeName -TestSecrets:$TestSecrets -ShowAllConfig:$ShowAllConfig -ValidateOnly:$ValidateOnly -UseRealSecrets:$UseRealSecrets -TestMode:$TestMode -DbEnv $DbEnv -OutputDirectory $OutputDirectory
    }
    else {
        # Show usage examples
        Write-Host 'Configuration Discovery Framework' -ForegroundColor Green
        Write-Host 'This script discovers and validates actual configuration values without hardcoded assumptions.' -ForegroundColor Yellow
        Write-Host ''
        Write-Host 'Usage examples:' -ForegroundColor Yellow
        Write-Host '  # Test configuration for MISDis DFI cluster with real secrets:' -ForegroundColor Gray
        Write-Host "  ./Test-ConfigurationDiscovery.ps1 -Application 'delius-mis' -EnvironmentName 'delius-mis-development' -NodeName 'ndmis-dev-dfi-1' -TestSecrets -UseRealSecrets" -ForegroundColor Gray
        Write-Host ''
        Write-Host '  # Test configuration for MISDis DIS cluster with real secrets:' -ForegroundColor Gray
        Write-Host "  ./Test-ConfigurationDiscovery.ps1 -Application 'delius-mis' -EnvironmentName 'delius-mis-development' -NodeName 'ndmis-dev-dis-1' -TestSecrets -UseRealSecrets" -ForegroundColor Gray
        Write-Host ''
        Write-Host '  # Test configuration for NCR preproduction (auto-determines dbenv as ''pp''):' -ForegroundColor Gray
        Write-Host "  ./Test-ConfigurationDiscovery.ps1 -Application 'nomis-combined-reporting' -EnvironmentName 'nomis-combined-reporting-preproduction' -NodeName 'pp-ncr-bods-2' -TestSecrets -UseRealSecrets" -ForegroundColor Gray
        Write-Host ''
        Write-Host '  # Test configuration for ONR test T2 environment (auto-detects as ''t2'' from node name):' -ForegroundColor Gray
        Write-Host "  ./Test-ConfigurationDiscovery.ps1 -Application 'oasys-national-reporting' -EnvironmentName 'oasys-national-reporting-test' -NodeName 't2-onr-bods-1' -TestSecrets -UseRealSecrets" -ForegroundColor Gray
        Write-Host ''
        Write-Host '  # Test configuration for ONR test T1 environment (explicit override):' -ForegroundColor Gray
        Write-Host "  ./Test-ConfigurationDiscovery.ps1 -Application 'oasys-national-reporting' -EnvironmentName 'oasys-national-reporting-test' -NodeName 't1-onr-bods-1' -TestSecrets -UseRealSecrets -DbEnv 't1'" -ForegroundColor Gray
        Write-Host ''
        Write-Host '  # Test configuration with custom dbenv (full flexibility):' -ForegroundColor Gray
        Write-Host "  ./Test-ConfigurationDiscovery.ps1 -Application 'nomis-combined-reporting' -EnvironmentName 'nomis-combined-reporting-production' -NodeName 'pd-ncr-bods-1' -TestSecrets -UseRealSecrets -DbEnv 'custom-env'" -ForegroundColor Gray
        Write-Host ''
        Write-Host '  # Show complete configuration without secret testing:' -ForegroundColor Gray
        Write-Host "  ./Test-ConfigurationDiscovery.ps1 -Application 'delius-mis' -EnvironmentName 'delius-mis-development' -NodeName 'ndmis-dev-dfi-1' -ShowAllConfig" -ForegroundColor Gray
        Write-Host ''
        Write-Host 'Interactive mode (prompts for parameters):' -ForegroundColor Yellow
        Write-Host '  ./Test-ConfigurationDiscovery.ps1' -ForegroundColor Gray
    }
}
