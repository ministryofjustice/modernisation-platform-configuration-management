<#
.SYNOPSIS
    Create an Active Directory Domain Controller in Modernisation-Platform

.DESCRIPTION
    

.PARAMETER DomainName
    
.EXAMPLE
    New-ModPlatformADDomain -DomainName "domain.name.root"
#>

[CmdletBinding()]
param (
  [string]$DomainName = "test.loc"
)

Import-Module ModPlatformAD -Force

$DomainNameString = ($DomainName -split "\." | ForEach-Object { "DC=$_" }) -join ","

New-ADOrganizationalUnit -Name "ModPlatformComputers" -Path $DomainNameString -Description "Modernisation Platform Computers" -ProtectedFromAccidentalDeletion $true

# set sub-level AD OU for Modernisation Platform Computers Environments
$topLevelOU = "OU=ModPlatformComputers"

$repoOwner = "ministryofjustice"
$repoName = "modernisation-platform-environments"
$repoPAth = "terraform/environments"

$environments = @("development", "test", "preproduction", "production")
$excludeTerraformEnvironments = @("example")

$ApiUrl = "https://api.github.com/repos/$repoOwner/$repoName/contents/$repoPAth"

$Response = Invoke-RestMethod -Uri $ApiUrl

$Response | Where-Object { $_.type -eq "dir" -and $excludeTerraformEnvironments -notcontains $_.name } | ForEach-Object { $_.name } | ForEach-Object {
    New-ADOrganizationalUnit -Name $_ -Path "$topLevelOU,$DomainNameString" -Description "Modernisation Platform Computers $_" -ProtectedFromAccidentalDeletion $true

    ForEach ($environment in $environments) {
        New-ADOrganizationalUnit -Name $environment -Path "OU=$_,$topLevelOU,$DomainNameString" -Description "Modernisation Platform Computers $_ $environment" -ProtectedFromAccidentalDeletion $true
    }
}

