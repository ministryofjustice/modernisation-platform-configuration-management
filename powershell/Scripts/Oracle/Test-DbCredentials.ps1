function Test-DbCredentials {
    [CmdletBinding()]
    param (
        [Parameter()]
        [hashtable]
        $Config
    )

    # Check database credentials BEFORE installer runs
    $typePath = "C:\app\oracle\product\19.0.0\client_1\ODP.NET\bin\4\Oracle.DataAccess.dll"

    $sysDbSecretName = "/oracle/database/$($Config.sysDbName)/passwords"
    $audDbSecretName = "/oracle/database/$($Config.audDbName)/passwords"

    # Get secret values, silently continue if they don't exist
    $bods_ips_system_owner = Get-SecretValue -SecretId $sysDbSecretName -SecretKey "bods_ips_system_owner" -ErrorAction SilentlyContinue
    $bods_ips_audit_owner = Get-SecretValue -SecretId $audDbSecretName -SecretKey "bods_ips_audit_owner" -ErrorAction SilentlyContinue

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
