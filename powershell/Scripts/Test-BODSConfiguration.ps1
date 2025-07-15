# BODS Configuration Testing Framework
# This script allows testing of configurations and response file generation without deployment

param (
    [Parameter(Mandatory)]
    [string]$EnvironmentName,
    [Parameter()]
    [string]$Application,
    [Parameter()]
    [string]$NodeName,
    [Parameter()]
    [switch]$TestSecrets,
    [Parameter()]
    [switch]$GenerateResponseFiles,
    [Parameter()]
    [string]$OutputDirectory = './TestOutput'
)

. (Join-Path $PSScriptRoot '..\Configs\unified_config_system.ps1')

function Test-BODSConfiguration {
    param(
        [Parameter()]
        [string]$EnvironmentName,
        
        [Parameter()]
        [string]$Application,
        
        [Parameter()]
        [string]$NodeName,
        
        [Parameter()]
        [switch]$TestSecrets,
        
        [Parameter()]
        [switch]$GenerateResponseFiles,
        
        [Parameter()]
        [string]$OutputDirectory = '.\TestOutput'
    )

    Write-Host '=== BODS Configuration Testing Framework ===' -ForegroundColor Green
    
    # If no parameters provided, run interactive mode
    if (-not $EnvironmentName -or -not $Application -or -not $NodeName) {
        Write-Host 'Running in interactive mode...' -ForegroundColor Yellow
        
        $Application = Read-Host 'Enter application (oasys-national-reporting, nomis-combined-reporting, delius-mis)'
        $EnvironmentName = Read-Host 'Enter environment name (e.g., oasys-national-reporting-test)'
        $NodeName = Read-Host 'Enter node name (e.g., t2-onr-bods-1)'
        
        $TestSecrets = (Read-Host 'Test secret retrieval? (y/n)') -eq 'y'
        $GenerateResponseFiles = (Read-Host 'Generate response files? (y/n)') -eq 'y'
    }

    # Create output directory
    if (-not (Test-Path $OutputDirectory)) {
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    }

    try {
        # Test configuration loading
        Write-Host "`n1. Testing Configuration Loading..." -ForegroundColor Cyan
        
        $additionalTags = @{
            Name       = $NodeName
            domainName = 'test.domain'
        }
        
        $config = Get-UnifiedConfig -EnvironmentName $EnvironmentName -Application $Application -AdditionalTags $additionalTags
        
        Write-Host '   ✓ Configuration loaded successfully' -ForegroundColor Green
        Write-Host "   Application: $($config.application ?? $Application)" -ForegroundColor Gray
        Write-Host "   Working Directory: $($config.WorkingDirectory)" -ForegroundColor Gray
        Write-Host "   Oracle Home: $($config.ORACLE_19C_HOME)" -ForegroundColor Gray
        Write-Host "   Secret Pattern: $($config.SecretConfig.secretPattern)" -ForegroundColor Gray
        
        # Save config to file for inspection
        $configOutputFile = Join-Path $OutputDirectory "config_$($Application)_$($EnvironmentName).json"
        $config | ConvertTo-Json -Depth 10 | Out-File $configOutputFile
        Write-Host "   Configuration saved to: $configOutputFile" -ForegroundColor Gray

        # Test secret patterns
        if ($TestSecrets) {
            Write-Host "`n2. Testing Secret Retrieval Patterns..." -ForegroundColor Cyan
            
            $secretTests = @(
                @{ Type = 'bods_passwords'; Key = 'bods_admin_password' },
                @{ Type = 'bods_config'; Key = 'ips_product_key' },
                @{ Type = 'service_accounts'; Key = $config.ServiceConfig.serviceUser }
            )
            
            foreach ($test in $secretTests) {
                try {
                    $secretValue = Get-SecretValueUnified -Config $config -SecretType $test.Type -SecretKey $test.Key -TestMode
                    Write-Host "   ✓ $($test.Type)/$($test.Key): $secretValue" -ForegroundColor Green
                }
                catch {
                    Write-Host "   ✗ $($test.Type)/$($test.Key): ERROR - $_" -ForegroundColor Red
                }
            }
        }

        # Generate response files
        if ($GenerateResponseFiles) {
            Write-Host "`n3. Generating Response Files..." -ForegroundColor Cyan
            
            $templates = @(
                'IPS_Primary_Template.ini',
                'DataServices_Primary_Template.ini'
            )
            
            foreach ($template in $templates) {
                try {
                    $outputFile = Join-Path $OutputDirectory "$($template -replace '_Template', "_$NodeName")"
                    $result = New-ResponseFileFromTemplate -Config $config -TemplateName $template -OutputPath $outputFile -TestMode
                    
                    Write-Host "   ✓ Generated: $outputFile" -ForegroundColor Green
                    Write-Host "     Command line args: $($result.CommandLineArgs.Count) parameters" -ForegroundColor Gray
                    
                    # Save command line args to separate file
                    $argsFile = $outputFile -replace '\.ini$', '_args.txt'
                    $result.CommandLineArgs | Out-File $argsFile
                    Write-Host "     Arguments saved to: $argsFile" -ForegroundColor Gray
                    
                }
                catch {
                    Write-Host "   ✗ Failed to generate $template`: $_" -ForegroundColor Red
                }
            }
        }

        # Validate critical paths
        Write-Host "`n4. Validating Configuration..." -ForegroundColor Cyan
        
        $validationTests = @(
            @{ Name = 'Oracle Home'; Path = $config.ORACLE_19C_HOME; Required = $true },
            @{ Name = 'Working Directory'; Path = $config.WorkingDirectory; Required = $true },
            @{ Name = 'App Directory'; Path = $config.AppDirectory; Required = $false },
            @{ Name = 'BIP Install Dir'; Path = $config.BIP_INSTALL_DIR; Required = $true }
        )
        
        foreach ($test in $validationTests) {
            if ([string]::IsNullOrEmpty($test.Path)) {
                if ($test.Required) {
                    Write-Host "   ✗ $($test.Name): NOT CONFIGURED" -ForegroundColor Red
                }
                else {
                    Write-Host "   ! $($test.Name): Not configured (optional)" -ForegroundColor Yellow
                }
            }
            else {
                Write-Host "   ✓ $($test.Name): $($test.Path)" -ForegroundColor Green
            }
        }

        # Check for required database configuration
        if ($config.DatabaseConfig.sysDbName -and $config.DatabaseConfig.audDbName) {
            Write-Host '   ✓ Database configuration present' -ForegroundColor Green
            Write-Host "     System DB: $($config.DatabaseConfig.sysDbName)" -ForegroundColor Gray
            Write-Host "     Audit DB: $($config.DatabaseConfig.audDbName)" -ForegroundColor Gray
        }
        else {
            Write-Host '   ! Database configuration incomplete' -ForegroundColor Yellow
        }

        Write-Host "`n=== Test Summary ===" -ForegroundColor Green
        Write-Host 'Configuration test completed successfully!' -ForegroundColor Green
        Write-Host "Output files saved to: $OutputDirectory" -ForegroundColor Gray
        
        return $config

    }
    catch {
        Write-Host "`n=== Test Failed ===" -ForegroundColor Red
        Write-Host "Error: $_" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
        throw
    }
}

function Compare-ConfigurationVersions {
    param(
        [Parameter(Mandatory)]
        [string]$Config1Path,
        
        [Parameter(Mandatory)]
        [string]$Config2Path,
        
        [Parameter()]
        [string]$OutputFile
    )

    Write-Host 'Comparing configurations...' -ForegroundColor Cyan
    
    $config1 = Get-Content $Config1Path | ConvertFrom-Json
    $config2 = Get-Content $Config2Path | ConvertFrom-Json
    
    $differences = @()
    
    function Compare-Objects {
        param($obj1, $obj2, $path = '')
        
        $keys1 = if ($obj1) { $obj1.PSObject.Properties.Name } else { @() }
        $keys2 = if ($obj2) { $obj2.PSObject.Properties.Name } else { @() }
        $allKeys = ($keys1 + $keys2) | Sort-Object | Get-Unique
        
        foreach ($key in $allKeys) {
            $currentPath = if ($path) { "$path.$key" } else { $key }
            
            $val1 = if ($obj1 -and $obj1.PSObject.Properties.Name -contains $key) { $obj1.$key } else { $null }
            $val2 = if ($obj2 -and $obj2.PSObject.Properties.Name -contains $key) { $obj2.$key } else { $null }
            
            if ($val1 -is [PSCustomObject] -and $val2 -is [PSCustomObject]) {
                Compare-Objects -obj1 $val1 -obj2 $val2 -path $currentPath
            }
            elseif ($val1 -ne $val2) {
                $differences += [PSCustomObject]@{
                    Path    = $currentPath
                    Config1 = $val1
                    Config2 = $val2
                    Type    = if ($val1 -eq $null) { 'Missing in Config1' } elseif ($val2 -eq $null) { 'Missing in Config2' } else { 'Different Values' }
                }
            }
        }
    }
    
    Compare-Objects -obj1 $config1 -obj2 $config2
    
    if ($differences.Count -eq 0) {
        Write-Host '   ✓ Configurations are identical' -ForegroundColor Green
    }
    else {
        Write-Host "   ! Found $($differences.Count) differences:" -ForegroundColor Yellow
        $differences | Format-Table -AutoSize
        
        if ($OutputFile) {
            $differences | Export-Csv $OutputFile -NoTypeInformation
            Write-Host "   Differences saved to: $OutputFile" -ForegroundColor Gray
        }
    }
    
    return $differences
}

# Example usage and testing
if ($MyInvocation.InvocationName -ne '.') {
    # If script is run directly (not dot-sourced), run the test function
    if ($Application -or $EnvironmentName -or $NodeName) {
        Test-BODSConfiguration -EnvironmentName $EnvironmentName -Application $Application -NodeName $NodeName -TestSecrets:$TestSecrets -GenerateResponseFiles:$GenerateResponseFiles -OutputDirectory $OutputDirectory
    }
    else {
        # Show usage examples if no parameters provided
        Write-Host 'BODS Configuration Testing Framework' -ForegroundColor Green
        Write-Host 'Usage examples:' -ForegroundColor Yellow
        Write-Host '  Test-BODSConfiguration' -ForegroundColor Gray
        Write-Host "  Test-BODSConfiguration -EnvironmentName 'oasys-national-reporting-test' -Application 'oasys-national-reporting' -NodeName 't2-onr-bods-1' -TestSecrets -GenerateResponseFiles" -ForegroundColor Gray
    }
}