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

    $groupExists = Get-ADGroup -Filter "Name -eq '$Group'" -Credential $ModPlatformADCredential -ErrorAction SilentlyContinue
    # Create the Group in AD
    if (-NOT($groupExists)) {
        New-ADGroup -Name $Group -Path $Path -Description $Description -Credential $ModPlatformADCredential -GroupScope "Global" -GroupCategory "Security"
    } else {
        Write-Host "Group: $Group already exists"
    }
    # NOTE:
    # GroupScope is set to Global, restricts the group to the current domain
    # GroupCategory is set to Security, related to access control and group policies in Active Directory
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
        [psobject]$Computer,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$ModPlatformADCredential
    )
    Write-Debug "Adding Member: $Member to Group: $Group"

    # Get the distinguishedName of the Computer
    $distinguishedName = (Get-ADComputer -Filter 'Name -eq $Computer' -Credential $ModPlatformADCredential -Properties *).DistinguishedName

    # Add the member to the Group in AD
    Add-ADGroupMember -Identity $Group -Members "$distinguishedName" -Credential $ModPlatformADCredential
}

function Add-ModPlatformGroupUser {
        [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [psobject]$Group,
        [Parameter(Mandatory=$true)]
        [psobject]$User,
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$ModPlatformADCredential
    )
    Write-Debug "adding $User to $Group"
    $distinguishedName = (Get-ADUser -Filter 'Name -eq $User' -Credential $ModPlatformADCredential -Properties *).DistinguishedName

    Add-ADGroupMember -Identity $Group -Members $distinguishedName -Credential $ModPlatformADCredential
}

Export-ModuleMember -Function New-ModPlatformADGroup
Export-ModuleMember -Function Add-ModPlatformGroupMember
Export-ModuleMember -Function Add-ModPlatformGroupUser
