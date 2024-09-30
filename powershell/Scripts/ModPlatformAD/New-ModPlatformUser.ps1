<#
    .SYNOPSIS
        Creates a new user in Active Directory
    .DESCRIPTION
        Creates a new user in Active Directory

#>
[CmdletBinding()]
param(
    [ValidateLength(1, 20)]
    [Parameter(Mandatory=$true)]
    [string]$Name,
    [Parameter(Mandatory=$true)]
    [string]$Path, # Adjusts the base domain DN as necessary
    [Parameter(Mandatory=$true)]
    [string]$Description,
    [Parameter(Mandatory=$true)]
    [string]$DomainNameFQDN,
    [Parameter(Mandatory=$true)]
    [string]$accountPassword
)
Import-Module ModPlatformAD -Force

$ErrorActionPreference = "Stop"

$ADConfig = Get-ModPlatformADConfig -DomainNameFQDN $DomainNameFQDN
$ADCredential = Get-ModPlatformADJoinCredential -ModPlatformADConfig $ADConfig

$securePassword = ConvertTo-SecureString -String $accountPassword -AsPlainText -Force

$newUserParams = @{
    Name = $Name
    Path = $Path
    Description = $Description
    Credential = $ADCredential
    accountPassword = $securePassword
}

New-ModPlatformADUser @newUserParams
