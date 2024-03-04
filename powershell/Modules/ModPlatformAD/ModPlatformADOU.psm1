function New-ADOrganizationalUnit {

<#
.SYNOPSIS
    Creates a New-ADOrganizationalUnit

.DESCRIPTION
    Using configuration returned from Get-ModPlatformADConfig, this function
    optionally assumes a role to access a secret containing the password of the
    domain join username. EC2 requires permissions to join the given role,
    a SSM parameter containing account IDs, and the aws cli.

.PARAMETER Name
    Name of the Organizational Unit to create

.PARAMETER Path
    The path of the Organizational Unit to create

.PARAMETER Description
    Description of the Organizational Unit to create

.PARAMETER ProtectedFromAccidentalDeletion
    Whether the Organizational Unit should be protected from accidental deletion, defaults to false

.EXAMPLE
    New-ADOrganizationalUnit -Name "TestOU" -Path "OU=Test,DC=example,DC=com" -Description "Test OU"

.OUTPUTS
        PSCredentialObject
#>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [bool]$ProtectedFromAccidentalDeletion = $false
    )

    $ou = Get-ADOrganizationalUnit -Filter "Name -eq '$Name'" -SearchBase $Path
    if ($ou) {
        Write-Host "Organizational Unit $Name already exists in $Path" -ForegroundColor Yellow
    } else {
        $ou = New-ADOrganizationalUnit -Name $Name -Path $Path -Description $Description -ProtectedFromAccidentalDeletion $ProtectedFromAccidentalDeletion
        Write-Host "Organizational Unit $Name created in $Path" -ForegroundColor Green
    }
}

Export-ModuleMember -Function New-ADOrganizationalUnit
