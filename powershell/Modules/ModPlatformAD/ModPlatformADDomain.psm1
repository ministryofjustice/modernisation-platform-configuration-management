function Install-ModPlatformADDomain {

<#
.SYNOPSIS
    Installs the Active Directory Domain Services Windows Feature and Domain

.DESCRIPTION
    TODO: Add this and Parameters

.PARAMETER DomainName
    Domain Name to create

.EXAMPLE
    Install-ModPlatformADDomain -DomainName "test.loc"

.OUTPUTS
    PSCredentialObject
#>

[CmdletBinding()]
param (
  [Parameter(Mandatory=$true)][string]$DomainName
)

    $ErrorActionPreference = "Stop"

    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

    # Get SafeModeAdministratorPassword from secrets of call ADCredential?

    Install-ADDSForest -DomainName $DomainName -InstallDNS -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" -LogPath "C:\Windows\NTDS" -SYSVOLPath "C:\Windows\SYSVOL" -Force -SafeModeAdministratorPassword (ConvertTo-SecureString $SafeModeAdministratorPassword -AsPlainText -Force)

}

Export-ModuleMember -Function Install-ModPlatformADDomain