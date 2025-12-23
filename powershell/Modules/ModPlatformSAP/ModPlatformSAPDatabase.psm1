
function Test-OracleConnection {
<#
.SYNOPSIS
    Test connectivity to Oracle database
#>
    param (
        [Parameter(Mandatory = $true)][String]$tnsName,
        [Parameter(Mandatory = $true)][String]$username,
        [Parameter(Mandatory = $true)][System.Security.SecureString]$securePassword
    )

    $TypePath = ($env:ORACLE_HOME + '\ODP.NET\bin\4\Oracle.DataAccess.dll')
    if (-Not (Test-Path $TypePath)) {
        Write-Error "Oracle Client not found: missing $TypePath"
    }
    Add-Type -Path $TypePath

    # Convert SecureString to plain text safely
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    # Create connection string
    $connectionString = "User Id=$username;Password=$plainPassword;Data Source=$tnsName"
    $connection = New-Object Oracle.DataAccess.Client.OracleConnection($connectionString)

    try {
        $connection.Open()
        Write-Host "${tnsName}: ${username}: Connection successful!"
        return 0
    }
    catch {
        Write-Host "${tnsName}: ${username}: Connection failed: $($_.Exception.Message)"
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

Export-ModuleMember -Function Test-OracleConnection
