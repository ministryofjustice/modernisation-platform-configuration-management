<#
    .SYNOPSIS
        Creates a new Group in Active Directory
    .DESCRIPTION
        Creates a new Group in Active Directory
    .PARAMETER Group
        Name of the group to create
    .PARAMETER Path
        Full OU path to create the group in
    .PARAMETER Description
        Describe the group, otherwise all the things get very confusing
    .PARAMETER DomainNameFQDN
        Required to get the AD configuration
    .EXAMPLE
        New-ModPlatformGroup -Group "Oasys-ONR" -Path "OU=Groups,DC=example,DC=com" -Description "Shared groups for service user" -DomainNameFQDN "example.com"
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [psobject]$Group,
    [Parameter(Mandatory=$true)]
    [string]$Path, # Adjusts the base domain DN as necessary
    [Parameter(Mandatory=$true)]
    [string]$Description,
    [Parameter(Mandatory=$true)]
    [string]$DomainNameFQDN
)

Import-Module ModPlatformAD -Force

$ErrorActionPreference = "Stop"

$ADConfig = Get-ModPlatformADConfig -DomainNameFQDN $DomainNameFQDN
$ADCredential = Get-ModPlatformADJoinCredential -ModPlatformADConfig $ADConfig

New-ModPlatformADGroup -Group $Group -Path $Path -Description $Description -ModPlatformADCredential $ADCredential
