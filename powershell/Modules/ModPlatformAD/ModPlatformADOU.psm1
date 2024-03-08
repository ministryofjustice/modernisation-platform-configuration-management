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
    OU folder created
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

function Set-OUsAndApplyGPOs {
    param (
        [Parameter(Mandatory=$true)]
        [psobject]$OUs,
        [string]$ParentOUs = "",
        [string]$DomainNameFQDN # Adjust the base domain DN as necessary
    )

    $ParentDN = ($DomainNameFQDN -split "\." | ForEach-Object { "DC=$_" }) -join ","
    
    foreach ($ou in $OUs) {
        $currentOUDN = "OU=$($ou.name)"
        $ouDN = if ($ParentOUs -eq "") { "$currentOUDN,$DomainDN" } else { "$currentOUDN,$ParentOUs,$DomainDN" }
        
        # Check and create OU if it doesn't exist
        if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$ouDN'" -ErrorAction SilentlyContinue)) {
            New-ADOrganizationalUnit -Name $ou.name -Path $ParentDN -ProtectedFromAccidentalDeletion $false
            Write-Output "Created OU: $($ou.name) at $ouDN"
        }
        
        # # Apply GPOs TODO: put this back in and test recursively down the stack
        # foreach ($gpoName in $ou.GPOs) {
        #     # Assuming GPOs already exist, find and link them to the OU
        #     $gpo = Get-GPO -Name $gpoName -ErrorAction SilentlyContinue
        #     if ($gpo) {
        #         New-GPLink -Name $gpoName -Target $ouDN
        #         Write-Output "Linked GPO: $gpoName to OU: $($ou.name)"
        #     }
        #     else {
        #         Write-Output "GPO $gpoName does not exist and cannot be linked to OU: $($ou.name)"
        #     }
        # }
        
        # Recursive call for children OUs, if any, with the current OU DN as the new parent DN
        if ($ou.children) {
            $newParentOUs = if ($ParentOUs -eq "") { "$currentOUDN" } else { "$currentOUDN,$ParentOUs" }
            # Increase indentation for child OUs for visual hierarchy
            Set-OUHierarchy -OUs $ou.children -ParentOUs $newParentOUs -DomainNameFQDN $DomainNameFQDN
        }
    }
}

# Load YAML
# $yamlContent = Get-Content -Path "path\to\your\file.yaml" -Raw
# $adStructure = ConvertFrom-Yaml -Yaml $yamlContent

# # Start the recursive creation and linking process
# CreateOUsAndApplyGPOs -OUs $adStructure.ActiveDirectory.OUs


Export-ModuleMember -Function New-ADOrganizationalUnit
Export-ModuleMember -Function Set-OUsAndApplyGPOs
