# Test-ClusterConfig.ps1
# Test script to demonstrate the enhanced cluster-based configuration system
# Updated to force PSScriptAnalyzer re-analysis

# Import the unified config system
. (Join-Path $PSScriptRoot '..\Configs\unified_config_system.ps1')

function Test-ClusterConfiguration {
    param(
        [string]$Application = 'delius-mis',
        [string]$Environment = 'delius-mis-preproduction'
    )
    
    Write-Host '=== Testing Cluster-Based Configuration System ===' -ForegroundColor Green
    Write-Host "Application: $Application" -ForegroundColor Cyan
    Write-Host "Environment: $Environment" -ForegroundColor Cyan
    Write-Host ''
    
    # Test scenarios for different environments and clusters
    $testCases = @()
    
    if ($Environment -eq 'delius-mis-development') {
        $testCases = @(
            @{
                Name              = 'delius-mis-dev-dfi-1'
                Description       = 'Development primary node'
                ExpectedRole      = 'primary'
                ExpectedCluster   = $null  # No cluster for dev
                ExpectedConfigKey = 'delius-mis-development'
            },
            @{
                Name              = 'delius-mis-dev-dfi-2'
                Description       = 'Development secondary node'
                ExpectedRole      = 'secondary'
                ExpectedCluster   = $null
                ExpectedConfigKey = 'delius-mis-development'
            }
        )
    }
    else {
        # Preproduction test cases
        $testCases = @(
            @{
                Name              = 'delius-mis-stage-dfi-1'
                Description       = 'Stage cluster primary node'
                ExpectedRole      = 'primary'
                ExpectedCluster   = 'stage'
                ExpectedConfigKey = 'delius-mis-stage-dfi-1'
            },
            @{
                Name              = 'delius-mis-stage-dfi-2'
                Description       = 'Stage cluster secondary node'
                ExpectedRole      = 'secondary'
                ExpectedCluster   = 'stage'
                ExpectedConfigKey = 'delius-mis-stage-dfi-1'
            },
            @{
                Name              = 'delius-mis-pp-dfi-1'
                Description       = 'PP cluster primary node'
                ExpectedRole      = 'primary'
                ExpectedCluster   = 'pp'
                ExpectedConfigKey = 'delius-mis-pp-dfi-1'
            },
            @{
                Name              = 'delius-mis-pp-dfi-2'
                Description       = 'PP cluster secondary node'
                ExpectedRole      = 'secondary'
                ExpectedCluster   = 'pp'
                ExpectedConfigKey = 'delius-mis-pp-dfi-1'
            }
        )
    }
    
    foreach ($testCase in $testCases) {
        Write-Host "--- Testing: $($testCase.Description) ---" -ForegroundColor Yellow
        Write-Host "Machine Name: $($testCase.Name)" -ForegroundColor Gray
        
        try {
            $additionalTags = @{
                application = $Application
                Name        = $testCase.Name
                domainName  = 'delius-mis-preprod.local'
            }
            
            $config = Get-UnifiedConfig -EnvironmentName $Environment -Application $Application -AdditionalTags $additionalTags
            
            Write-Host '✓ Configuration loaded successfully' -ForegroundColor Green
            Write-Host "  Config Key: $($config.ConfigKey)" -ForegroundColor Gray
            Write-Host "  Detected Role: $($config.DetectedRole)" -ForegroundColor Gray
            Write-Host "  Cluster Name: $($config.ClusterName)" -ForegroundColor Gray
            Write-Host "  Primary Node: $($config.NodeConfig.cmsPrimaryNode)" -ForegroundColor Gray
            Write-Host "  Secondary Node: $($config.NodeConfig.cmsSecondaryNode)" -ForegroundColor Gray
            Write-Host "  Database (Sys): $($config.DatabaseConfig.sysDbName)" -ForegroundColor Gray
            Write-Host "  Database (Aud): $($config.DatabaseConfig.audDbName)" -ForegroundColor Gray
            
            # Verify expectations
            $validationErrors = @()
            if ($config.DetectedRole -ne $testCase.ExpectedRole) {
                $validationErrors += "Expected role '$($testCase.ExpectedRole)' but got '$($config.DetectedRole)'"
            }
            if ($testCase.ExpectedCluster -ne $null -and $config.ClusterName -ne $testCase.ExpectedCluster) {
                $validationErrors += "Expected cluster '$($testCase.ExpectedCluster)' but got '$($config.ClusterName)'"
            }
            if ($config.ConfigKey -ne $testCase.ExpectedConfigKey) {
                $validationErrors += "Expected config key '$($testCase.ExpectedConfigKey)' but got '$($config.ConfigKey)'"
            }
            
            if ($validationErrors.Count -eq 0) {
                Write-Host '✓ All expectations met!' -ForegroundColor Green
            }
            else {
                Write-Host '✗ Test failed:' -ForegroundColor Red
                foreach ($errorMsg in $validationErrors) {
                    Write-Host "  - $errorMsg" -ForegroundColor Red
                }
            }
            
        }
        catch {
            Write-Host "✗ Configuration failed: $_" -ForegroundColor Red
        }
        
        Write-Host ''
    }
}

function Test-DevelopmentEnvironment {
    Write-Host '=== Testing Development Environment ===' -ForegroundColor Green
    
    $testNodes = @(
        @{ Name = 'delius-mis-dev-dfi-1'; Expected = 'primary'; Environment = 'delius-mis-development'; Application = 'delius-mis' },
        @{ Name = 'delius-mis-dev-dfi-2'; Expected = 'secondary'; Environment = 'delius-mis-development'; Application = 'delius-mis' },
        @{ Name = 'ndmis-dev-dfi-1'; Expected = 'primary'; Environment = 'delius-mis-development'; Application = 'delius-mis' },  # Normalized name
        @{ Name = 'ndmis-dev-dfi-2'; Expected = 'secondary'; Environment = 'delius-mis-development'; Application = 'delius-mis' }   # Normalized name
    )
    
    foreach ($testNode in $testNodes) {
        Write-Host "Testing Dev node: $($testNode.Name) (expecting $($testNode.Expected))" -ForegroundColor Yellow
        
        $additionalTags = @{
            application = $testNode.Application
            Name        = $testNode.Name
            domainName  = 'delius-mis-dev.local'
        }
        
        try {
            $config = Get-UnifiedConfig -EnvironmentName $testNode.Environment -Application $testNode.Application -AdditionalTags $additionalTags
            
            Write-Host "  Config Key: $($config.ConfigKey)" -ForegroundColor Gray
            Write-Host "  Detected Role: $($config.DetectedRole)" -ForegroundColor Gray
            Write-Host "  Cluster: $($config.ClusterName)" -ForegroundColor Gray
            Write-Host "  Database: $($config.DatabaseConfig.sysDbName)" -ForegroundColor Gray
            Write-Host "  Primary Node: $($config.NodeConfig.cmsPrimaryNode)" -ForegroundColor Gray
            Write-Host "  Secondary Node: $($config.NodeConfig.cmsSecondaryNode)" -ForegroundColor Gray
            
            $validationErrors = @()
            if ($config.DetectedRole -ne $testNode.Expected) {
                $validationErrors += "Wrong role: expected $($testNode.Expected), got $($config.DetectedRole)"
            }
            if ($config.ConfigKey -ne $testNode.Environment) {
                $validationErrors += "Wrong config key: expected $($testNode.Environment), got $($config.ConfigKey)"
            }
            
            if ($validationErrors.Count -eq 0) {
                Write-Host '✓ Correct configuration detected' -ForegroundColor Green
            }
            else {
                Write-Host '✗ Configuration issues:' -ForegroundColor Red
                foreach ($errorMsg in $validationErrors) {
                    Write-Host "  - $errorMsg" -ForegroundColor Red
                }
            }
        }
        catch {
            Write-Host "✗ Configuration failed: $_" -ForegroundColor Red
        }
        
        Write-Host ''
    }
}

function Test-ONRMultipleCluster {
    Write-Host '=== Testing ONR Multiple Clusters ===' -ForegroundColor Green
    
    $testNodes = @(
        @{ Name = 't2-onr-bods-1'; Expected = 'primary'; Cluster = 'cluster1'; Database = 'T2BOSYS' },
        @{ Name = 't2-onr-bods-2'; Expected = 'secondary'; Cluster = 'cluster1'; Database = 'T2BOSYS' }
    )
    
    foreach ($testNode in $testNodes) {
        Write-Host "Testing ONR node: $($testNode.Name) (expecting $($testNode.Expected) in $($testNode.Cluster))" -ForegroundColor Yellow
        
        $additionalTags = @{
            application = 'oasys-national-reporting'
            Name        = $testNode.Name
            domainName  = 'azure.noms.root'
        }
        
        $config = Get-UnifiedConfig -EnvironmentName 'oasys-national-reporting-test' -Application 'oasys-national-reporting' -AdditionalTags $additionalTags
        
        Write-Host "  Config Key: $($config.ConfigKey)" -ForegroundColor Gray
        Write-Host "  Detected Role: $($config.DetectedRole)" -ForegroundColor Gray
        Write-Host "  Cluster: $($config.ClusterName)" -ForegroundColor Gray
        Write-Host "  Database: $($config.DatabaseConfig.sysDbName)" -ForegroundColor Gray
        
        $errorMessages = @()
        if ($config.DetectedRole -ne $testNode.Expected) {
            $errorMessages += "Wrong role: expected $($testNode.Expected), got $($config.DetectedRole)"
        }
        if ($config.ClusterName -ne $testNode.Cluster) {
            $errorMessages += "Wrong cluster: expected $($testNode.Cluster), got $($config.ClusterName)"
        }
        if ($config.DatabaseConfig.sysDbName -ne $testNode.Database) {
            $errorMessages += "Wrong database: expected $($testNode.Database), got $($config.DatabaseConfig.sysDbName)"
        }
        
        if ($errorMessages.Count -eq 0) {
            Write-Host '✓ Correct configuration detected' -ForegroundColor Green
        }
        else {
            Write-Host '✗ Configuration issues:' -ForegroundColor Red
            foreach ($errorMsg in $errorMessages) {
                Write-Host "  - $errorMsg" -ForegroundColor Red
            }
        }
        
        Write-Host ''
    }
}

function Test-BackwardCompatibility {
    Write-Host '=== Testing Backward Compatibility ===' -ForegroundColor Green
    
    # Test that machines not in cluster configs fall back to environment configs
    $testCases = @(
        @{
            Application = 'oasys-national-reporting'
            Environment = 'oasys-national-reporting-development'
            MachineName = 'dev-onr-bods-1'  # Not in any cluster config
            Description = 'Development environment fallback'
        },
        @{
            Application = 'nomis-combined-reporting'
            Environment = 'nomis-combined-reporting-development'
            MachineName = 'dev-ncr-bods-1'  # Not in any cluster config
            Description = 'NCR development fallback'
        }
    )
    
    foreach ($testCase in $testCases) {
        Write-Host "Testing: $($testCase.Description)" -ForegroundColor Yellow
        Write-Host "Machine: $($testCase.MachineName)" -ForegroundColor Gray
        
        $additionalTags = @{
            application = $testCase.Application
            Name        = $testCase.MachineName
            domainName  = 'test.local'
        }
        
        try {
            $config = Get-UnifiedConfig -EnvironmentName $testCase.Environment -Application $testCase.Application -AdditionalTags $additionalTags
            
            Write-Host "  Config Key: $($config.ConfigKey)" -ForegroundColor Gray
            Write-Host "  Detected Role: $($config.DetectedRole)" -ForegroundColor Gray
            
            if ($config.ConfigKey -eq $testCase.Environment) {
                Write-Host '✓ Correctly fell back to environment config' -ForegroundColor Green
            }
            else {
                Write-Host "✗ Unexpected config key: $($config.ConfigKey)" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "✗ Configuration failed: $_" -ForegroundColor Red
        }
        
        Write-Host ''
    }
}

# Run tests if script is executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Test-ClusterConfiguration -Environment 'delius-mis-preproduction'
    Test-DevelopmentEnvironment
    Test-ONRMultipleCluster
    Test-BackwardCompatibility
}
