function Get-Config {
    $tokenParams = @{
        TimeoutSec = 10
        Headers    = @{"X-aws-ec2-metadata-token-ttl-seconds" = 3600 }
        Method     = 'PUT'
        Uri        = 'http://169.254.169.254/latest/api/token'
    }
    $Token = Invoke-RestMethod @tokenParams

    $instanceIdParams = @{
        TimeoutSec = 10
        Headers    = @{"X-aws-ec2-metadata-token" = $Token }
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
    $EnvironmentNameTag = ($Tags.Tags | Where-Object { $_.Key -eq "environment-name" }).Value

    $ApplicationTag = ($Tags.Tags | Where-Object { $_.Key -eq "application" }).Value
    
    # FIXME: This won't work in a sustainable way - no longer used
    # $dbenvTag = ($Tags.Tags | Where-Object { $_.Key -eq "delius-mis-environment" }).Value

    $nameTag = ($Tags.Tags | Where-Object { $_.Key -eq "Name" }).Value

    $domainName = ($Tags.Tags | Where-Object { $_.Key -eq "domain-name" }).Value

    $serverType = ($Tags.Tags | Where-Object { $_.Key -eq "server-type" }).Value

    if ($ApplicationTag -eq "oasys-national-reporting") {
        $configPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Configs\ONR\onr_config.ps1"
    }
    elseif ($ApplicationTag -eq "nomis-combined-reporting") {
        $configPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Configs\NCR\ncr_config.ps1"
    }
    else { # used for MISDis, needs retrofitting to NCR and ONR to remove this if else entirely
        Write-Host "Using Server-Type tag to determine config path"
        $configPath = Join-Path -Path $PSScriptRoot -ChildPath "..\..\Configs\$serverType\$($serverType)_config.ps1"
    }

    # dot source the config file containing $GlobalConfig
    . $configPath

    if (-not $GlobalConfig.Contains($EnvironmentNameTag)) {
        Write-Error "Unexpected environment-name tag value $EnvironmentNameTag"
    }

    $additionalConfig = @{
        application = $ApplicationTag
        # dbenv       = $dbenvTag
        Name        = $nameTag
        domainName  = $domainName
    }

    # Merge all config hashtables into one
    $mergedConfig = @{}
    $GlobalConfig.all.GetEnumerator() | ForEach-Object { $mergedConfig[$_.Key] = $_.Value }
    $GlobalConfig[$EnvironmentNameTag].GetEnumerator() | ForEach-Object { $mergedConfig[$_.Key] = $_.Value }
    $additionalConfig.GetEnumerator() | ForEach-Object { $mergedConfig[$_.Key] = $_.Value }
    return $mergedConfig
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

function Test-DbCredentials {
    [CmdletBinding()]
    param (
        [Parameter()]
        [hashtable]
        $Config
    )

    # Check database credentials BEFORE installer runs
    $typePath = "C:\app\oracle\product\19.0.0\client_1\ODP.NET\bin\4\Oracle.DataAccess.dll"

    # Not used because referencing SecretId directly FIXME: needs changing later
    $sysDbSecretName = "/oracle/database/$($Config.sysDbName)/passwords"
    $audDbSecretName = "/oracle/database/$($Config.audDbName)/passwords"

    # Get secret values, silently continue if they don't exist
    $bods_ips_system_owner = Get-SecretValue -SecretId "delius-mis-dev-oracle-dsd-db-application-passwords" -SecretKey "dfi_mod_ipscms" -ErrorAction SilentlyContinue
    # $bods_ips_audit_owner = Get-SecretValue -SecretId $audDbSecretName -SecretKey "bods_ips_audit_owner" -ErrorAction SilentlyContinue
    $bods_ips_audit_owner = Get-SecretValue -SecretId "delius-mis-dev-oracle-dsd-db-application-passwords" -SecretKey "dfi_mod_ipsaud" -ErrorAction SilentlyContinue

    # Define an array of database configurations
    $dbConfigs = @(
        @{
            Name     = "$($Config.sysDbName)"
            Username = "bods_ips_system_owner"
            Password = $bods_ips_system_owner
        },
        @{
            Name     = "$($Config.audDbName)"
            Username = "bods_ips_audit_owner"
            Password = $bods_ips_audit_owner
        }
    )

    # Loop through each database configuration
    foreach ($db in $dbConfigs) {
        $securePassword = ConvertTo-SecureString -String $db.Password -AsPlainText -Force
        $return = Test-DatabaseConnection -typePath $typePath -tnsName $db.Name -username $db.Username -securePassword $securePassword
        if ($return -ne 0) {
            Write-Host "Connection to $($db.Name) failed. Exiting."
            exit 1
        }
        Write-Host "Connection to $($db.Name) successful."
    }

    Write-Host "All database connections successful."

}

# Reason for doing this is because the installer will silently fail if the database credentials are not correct.
Test-DbCredentials
