<#
.SYNOPSIS
    Create Group Policy Objects (GPOs) for the given Modernisation Platform environment
    GPO's need to be created BEFORE they can be linked to an OU.

.DESCRIPTION
    Pulls in the GPO definitions from the given YAML file and creates the GPOs in the given domain.

.PARAMETER DomainNameFQDN
    Specify the FQDN of the domain name to join

.PARAMETER ConfigFilePath
    Specify the *.yaml config file path for the given AD configuration

.EXAMPLE
    ./New-ModPlatformGPO.ps1 -DomainNameFQDN "test.loc" -ConfigFilePath "config.yaml"

.OUTPUTS
    
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)][string]$DomainNameFQDN,
    [Parameter(Mandatory=$true)][string]$ConfigFilePath
)

Install-Module -Name powershell-yaml -Force -SkipPublisherCheck

Import-Module ModPlatformAD -Force

Import-Module powershell-yaml -Force

# Load YAML
$config = Get-Content -Raw -Path $ConfigFilePath | ConvertFrom-Yaml

foreach ($gpo in $config.GPOs) {
    New-GPO -Name $gpo.name -Domain $DomainNameFQDN -Comment $gpo.comment
    Set-GPRegistryValue -Name $gpo.name -Key $gpo.key -ValueName $gpo.valuename -Type $gpo.type -Value $gpo.value
}
