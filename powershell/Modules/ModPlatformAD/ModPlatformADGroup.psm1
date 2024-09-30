function New-ModPlatformADGroup {
    <#
    .SYNOPSIS
        Creates a new Group in Active Directory
    .DESCRIPTION
        Creates a new Group in Active Directory
    .PARAMETER Group
        The Group to create
    .PARAMETER Path
        The path of the Group to create
    .PARAMETER Description
        The description of the Group to create, we really should use this as it'll help with management
    .PARAMETER ModPlatformADCredential
        The AD credential as returned from Get-ModPlatformADJoinCredential function
    .OUTPUTS
        Group is created
    .EXAMPLE

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
        [System.Management.Automation.PSCredential]$ModPlatformADCredential
    )
    Write-Debug "Creating Group: $Group"
    Write-Debug "Creating Path: $Path"

    # Create the Group in AD
    New-ADGroup -Name $Group -Path $Path -Description $Description -Credential $ModPlatformADCredential
}

function Add-ModPlatformGroupMember {
    <#
    .SYNOPSIS
        Adds a user, service account or computer to a Group in Active Directory
    .DESCRIPTION
        Adds a user, service account or computer to a Group in Active Directory
    .PARAMETER Group
        The Group to add the member to
    .PARAMETER Member
        The member to add to the Group, can be a user, EC2 instance or service account. Groups can also be added to other groups.
    .PARAMETER ModPlatformADCredential
        The AD credential as returned from Get-ModPlatformADJoinCredential function
    .OUTPUTS
        Member is added to the Group
    .EXAMPLE

    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [psobject]$Group,
        [Parameter(Mandatory=$true)]
        [psobject]$Member,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$ModPlatformADCredential
    )
    Write-Debug "Adding Member: $Member to Group: $Group"

    # Add the member to the Group in AD
    Add-ADGroupMember -Identity $Group -Members $Member -Credential $ModPlatformADCredential
}

Export-ModuleMember -Function New-ModPlatformADGroup
Export-ModuleMember -Function Add-ModPlatformGroupMember
