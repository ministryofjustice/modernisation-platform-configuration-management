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
    [string]$OutputDirectory = './ConfigDiscovery'
)

. (Join-Path $PSScriptRoot '..\Configs\unified_config_system.ps1')

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

        # Step 4: Secret Testing (if requested)
        if ($TestSecrets) {
            Write-Host '4. Secret Configuration Testing...' -ForegroundColor Cyan
            
            # Build secret tests dynamically from the configuration's secret keys
            $secretTests = @()
            
            if ($config.ContainsKey('SecretConfig') -and $config.SecretConfig.ContainsKey('secretKeys')) {
                # Use explicit secret keys from configuration - only test keys that actually exist
                $secretKeys = $config.SecretConfig.secretKeys
                
                $secretTests = @()
                
                # Only add tests for keys that are actually defined in the configuration
                if ($secretKeys.ContainsKey('bodsAdminPassword')) {
                    $secretTests += @{ Type = 'bods_passwords'; Key = $secretKeys.bodsAdminPassword; Description = 'BODS Admin Password' }
                }
                if ($secretKeys.ContainsKey('bodsSubversionPassword')) {
                    $secretTests += @{ Type = 'bods_passwords'; Key = $secretKeys.bodsSubversionPassword; Description = 'BODS Subversion Password' }
                }
                if ($secretKeys.ContainsKey('ipsProductKey')) {
                    $secretTests += @{ Type = 'bods_config'; Key = $secretKeys.ipsProductKey; Description = 'IPS Product Key' }
                }
                if ($secretKeys.ContainsKey('dataServicesProductKey')) {
                    $secretTests += @{ Type = 'bods_config'; Key = $secretKeys.dataServicesProductKey; Description = 'DataServices Product Key' }
                }
                if ($secretKeys.ContainsKey('serviceUserPassword')) {
                    $secretTests += @{ Type = 'service_accounts'; Key = $secretKeys.serviceUserPassword; Description = 'Service Account Password' }
                }
                if ($secretKeys.ContainsKey('sysDbUserPassword')) {
                    $secretTests += @{ Type = 'sys_db'; Key = $secretKeys.sysDbUserPassword; Description = 'System Database User Password' }
                }
                if ($secretKeys.ContainsKey('audDbUserPassword')) {
                    $secretTests += @{ Type = 'aud_db'; Key = $secretKeys.audDbUserPassword; Description = 'Audit Database User Password' }
                }
            }
            else {
                # Fallback to legacy hardcoded keys for backward compatibility
                Write-Host '   ⚠️ Using fallback secret keys (legacy configuration detected)' -ForegroundColor Yellow
                $secretTests = @(
                    @{ Type = 'bods_passwords'; Key = 'bods_admin_password'; Description = 'BODS Admin Password (Legacy)' },
                    @{ Type = 'bods_config'; Key = 'ips_product_key'; Description = 'IPS Product Key (Legacy)' },
                    @{ Type = 'bods_config'; Key = 'data_services_product_key'; Description = 'DataServices Product Key (Legacy)' },
                    @{ Type = 'service_accounts'; Key = $config.ServiceConfig.serviceUser; Description = 'Service Account (Legacy)' }
                )
            }
            
            $secretResults = @()
            foreach ($test in $secretTests) {
                try {
                    # Use TestMode unless UseRealSecrets is specified
                    $secretValue = if ($UseRealSecrets) {
                        Get-SecretValueUnified -Config $config -SecretType $test.Type -SecretKey $test.Key
                    }
                    else {
                        Get-SecretValueUnified -Config $config -SecretType $test.Type -SecretKey $test.Key -TestMode
                    }
                    
                    # Check if secret was actually retrieved
                    if ($null -eq $secretValue -or $secretValue -eq '') {
                        $secretResults += @{
                            Description = $test.Description
                            Type        = $test.Type
                            Key         = $test.Key
                            Status      = 'FAILED'
                            Value       = $null
                            Error       = 'Secret not found or returned empty value'
                        }
                        Write-Host "   ❌ $($test.Description): Secret not found or empty" -ForegroundColor Red
                    }
                    else {
                        $secretResults += @{
                            Description = $test.Description
                            Type        = $test.Type
                            Key         = $test.Key
                            Status      = 'SUCCESS'
                            Value       = if ($secretValue.Length -gt 10) { "$($secretValue.Substring(0,10))..." } else { $secretValue }
                            Error       = $null
                        }
                        Write-Host "   ✅ $($test.Description): Retrieved successfully" -ForegroundColor Green
                    }
                }
                catch {
                    $secretResults += @{
                        Description = $test.Description
                        Type        = $test.Type
                        Key         = $test.Key
                        Status      = 'ERROR'
                        Value       = $null
                        Error       = $_.Exception.Message
                    }
                    Write-Host "   ❌ $($test.Description): $($_.Exception.Message)" -ForegroundColor Red
                }
            }
            
            # Save secret test results
            $secretOutputFile = Join-Path $OutputDirectory "secret-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
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
            $result = Test-ConfigurationDiscovery -Application $Application -Environment $Environment -NodeName $nodeName -ValidateOnly -UseRealSecrets:$UseRealSecrets -OutputDirectory $OutputDirectory
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
        Test-ConfigurationDiscovery -Application $Application -Environment $EnvironmentName -NodeName $NodeName -TestSecrets:$TestSecrets -ShowAllConfig:$ShowAllConfig -ValidateOnly:$ValidateOnly -UseRealSecrets:$UseRealSecrets -OutputDirectory $OutputDirectory
    }
    else {
        # Show usage examples
        Write-Host 'Configuration Discovery Framework' -ForegroundColor Green
        Write-Host 'This script discovers and validates actual configuration values without hardcoded assumptions.' -ForegroundColor Yellow
        Write-Host ''
        Write-Host 'Usage examples:' -ForegroundColor Yellow
        Write-Host "  ./Test-ConfigurationDiscovery.ps1 -Application 'delius-mis' -EnvironmentName 'delius-mis-development' -NodeName 'delius-mis-dev-dfi-1' -ShowAllConfig" -ForegroundColor Gray
        Write-Host "  ./Test-ConfigurationDiscovery.ps1 -Application 'oasys-national-reporting' -EnvironmentName 'oasys-national-reporting-test' -NodeName 't2-onr-bods-1' -TestSecrets" -ForegroundColor Gray
        Write-Host ''
        Write-Host 'Interactive mode (prompts for parameters):' -ForegroundColor Yellow
        Write-Host '  ./Test-ConfigurationDiscovery.ps1' -ForegroundColor Gray
    }
}
