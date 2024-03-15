function Set-OUsAndApplyGPOs {
<#
.SYNOPSIS
    Recursively creates Organizational Units (OUs) and applies Group Policy Objects (GPOs) to the given domain
.DESCRIPTION
    Recursively creates Organizational Units (OUs) and applies Group Policy Objects (GPOs) to the given domain
.PARAMETER Ou
    The OU to create
.PARAMETER Path
    The path of the OU to create
.PARAMETER ProtectedFromAccidentalDeletion
    Whether the OU should be protected from accidental deletion, defaults to false
    In production environments, it is recommended to set this to true
.OUTPUTS
    OU folder created
#>
    param (
        [Parameter(Mandatory=$true)]
        [psobject]$Ou,
        [Parameter(Mandatory=$true)]
        [string]$Path, # Adjusts the base domain DN as necessary
        [bool]$ProtectedFromAccidentalDeletion = $false 
    )
    Write-Debug "Creating OU: $($ou.name)"
    Write-Debug "Creating Path: $Path"
    Write-Debug "Description: $($ou.description)"

    # Create the OU in AD
    New-ADOrganizationalUnit -Name $ou.name -Path $path -Description $ou.description -ProtectedFromAccidentalDeletion $ProtectedFromAccidentalDeletion

    # Append the OU name to the path for the next level
    $ouPath = "OU=$($ou.name),$path"

    if ($ou.gpos) {
        foreach ($gpo in $ou.gpos) {
            Write-Debug "Applying GPO: $gpo to Target OU: $ouPath"
            # Apply the GPO to the OU
            New-GPLink -Name $gpo -Target $ouPath
        }
    }

    # If the OU has children, call the function recursively
    if ($ou.children) {
        foreach ($child in $ou.children) {
            Set-OUsAndApplyGPOs -ou $child -path $ouPath
        }
    }
}

# Export-ModuleMember -Function Set-OUsAndApplyGPOs
