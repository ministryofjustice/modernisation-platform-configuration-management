function Get-ModPlatformADUser {
    <#
    .SYNOPSIS
        Gets a user from Active Directory
    .DESCRIPTION
        Gets a user from Active Directory, primarily to check whether the user already exists or not
    .PARAMETER Name
        Name of the user to get
    .PARAMETER Credential
        The AD credential as returned from Get-ModPlatformADJoinCredential function
    .OUTPUTS
        User is returned
    .EXAMPLE
        Get-ModPlatformADUser -Name "svc-MyService" -Credential
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$ModPlatformADCredential
    )
    Get-ADUser -Filter "Name -eq $Name" -Credential $ADCredential
}

function New-ModPlatformADUser {
    <#
    .SYNOPSIS
        Creates a new User in Active Directory, primarily for creating SERVICE accounts
    .DESCRIPTION
        Creates a new Group in Active Directory, primarily for creating SERVICE accounts
    .PARAMETER Name
        Service user name, must be 20 characters or less, can include - but not other special characters or underscores
    .PARAMETER Path
        The path of the User to create
    .PARAMETER Description
        The description of the User to create, we really should use this as it'll help with management
    .PARAMETER ModPlatformADCredential
        The AD credential as returned from Get-ModPlatformADJoinCredential function
    .PARAMETER accountPassword
        Must be a SecureString, pull the value from AWS Secrets Manager and use (ConvertTo-SecureString $SecretValue -AsPlainText -Force) to convert it
    .OUTPUTS
        User is created
    .EXAMPLE

    #>
    [CmdletBinding()]
    param (
        [ValidateLength(1, 20)]
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Path, # Adjusts the base domain DN as necessary
        [Parameter(Mandatory=$true)]
        [string]$Description,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$ModPlatformADCredential,
        [Parameter(Mandatory=$true)]
        [System.Security.SecureString]$accountPassword
    )
    Write-Debug "Creating Group: $Group"
    Write-Debug "Creating Path: $Path"

    $newADUserParams = @{
        Name = $Name
        Path = $Path
        Description = $Description
        AccountPassword = $accountPassword
        Type = "User"
        Credential = $ModPlatformADCredential
        CannotChangePassword = $true
        PasswordNeverExpires = $true
        Enabled = $true
        ChangePasswordAtLogon = $false
    }

    if (Get-ModPlatformADUser -Filter "Name -eq '$Name'" -Credential $ModPlatformADCredential) {
        Write-Warning "User $Name already exists"
        return
    } else {
        Write-Debug "Creating User: $Name"
        New-ADUser @newADUserParams
    }
}

Export-ModuleMember -Function New-ModPlatformADUser
