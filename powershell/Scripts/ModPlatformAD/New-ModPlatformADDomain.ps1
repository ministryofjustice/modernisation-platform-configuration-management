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

Install-ModPlatformADDomain -DomainName $DomainName