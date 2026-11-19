<#
.SYNOPSIS
    Set SMB share permissions
#>

[CmdletBinding()]
param (
    [string]$Path,
    [Parameter(Mandatory = $false)][string[]]$FullControlUsers = @("BUILTIN\Administrators", "NT AUTHORITY\SYSTEM"),
    [Parameter(Mandatory = $false)][string[]]$ModifyUsers = @(),
    [Parameter(Mandatory = $false)][string[]]$ReadOnlyUsers = @()
)

$ErrorActionPreference = "Stop"

# 1. Validate Target Directory Exists
if (-not (Test-Path -Path $Path)) {
    throw "$Path - ERROR: Target directory does not exist"
}

# 2. Helper: Resolve Account Name to SecurityIdentifier (SID)
function Resolve-AccountSid {
    param ([string]$AccountName)

    if ($AccountName -match '^\.\\(.+)$') {
        $AccountName = "$env:COMPUTERNAME\$($Matches[1])"
    }

    try {
        $NtAccount = New-Object System.Security.Principal.NTAccount($AccountName)
        return $NtAccount.Translate([System.Security.Principal.SecurityIdentifier])
    } catch {
        throw "$Path - ERROR: Could not resolve account '$AccountName'. Error: $_"
    }
}

# 3. Build Desired State Map (SID String -> Desired FileSystemRights)
$DesiredPermissions = @{} # Key: SID.Value, Value: @{ Sid = $Sid; Rights = [FileSystemRights]; Name = $Name }

# Process User Arrays in Ascending Precedence (ReadOnly -> Modify -> FullControl)
foreach ($User in $ReadOnlyUsers) {
    if ([string]::IsNullOrWhiteSpace($User)) { continue }
    $Sid = Resolve-AccountSid -AccountName $User
    $DesiredPermissions[$Sid.Value] = @{
        Sid    = $Sid
        Rights = [System.Security.AccessControl.FileSystemRights]::ReadAndExecute
        Name   = $User
    }
}

foreach ($User in $ModifyUsers) {
    if ([string]::IsNullOrWhiteSpace($User)) { continue }
    $Sid = Resolve-AccountSid -AccountName $User
    $DesiredPermissions[$Sid.Value] = @{
        Sid    = $Sid
        Rights = [System.Security.AccessControl.FileSystemRights]::Modify
        Name   = $User
    }
}

foreach ($User in $FullControlUsers) {
    if ([string]::IsNullOrWhiteSpace($User)) { continue }
    $Sid = Resolve-AccountSid -AccountName $User
    $DesiredPermissions[$Sid.Value] = @{
        Sid    = $Sid
        Rights = [System.Security.AccessControl.FileSystemRights]::FullControl
        Name   = $User
    }
}

if ($DesiredPermissions.Count -eq 0) {
    throw "$Path - ERROR: No target users specified. Not removing all permissions"
}

# 4. Inspect Current ACL and Reconcile Differences
$Acl = Get-Acl -Path $Path
$AclModified = $false

# Ensure inheritance is disabled so inherited rules (like BUILTIN\Users) are removed
if (-not $Acl.AreAccessRulesProtected) {
    # $true = disable inheritance, $false = drop inherited rules
    $Acl.SetAccessRuleProtection($true, $false)
    $AclModified = $true
    Write-Output "$Path - Disabled NTFS inheritance and cleared inherited rules"
}

# Remove any existing rules for SIDs NOT in $DesiredPermissions (or Deny rules)
foreach ($Rule in @($Acl.Access)) {
    if ($Rule.IsInherited) { continue }

    $RuleSidValue = $null
    try {
        $RuleSidValue = $Rule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
    } catch {
        # Unresolvable/orphaned SID -> remove it
        $Acl.RemoveAccessRuleSpecific($Rule) | Out-Null
        $AclModified = $true
        Write-Output "$Path - removed orphaned SID rule ($($Rule.IdentityReference.Value))"
        continue
    }

    if (-not $DesiredPermissions.ContainsKey($RuleSidValue) -or $Rule.AccessControlType -ne "Allow") {
        $Acl.RemoveAccessRuleSpecific($Rule) | Out-Null
        $AclModified = $true
        Write-Output "$Path - removed unauthorized rule for '$($Rule.IdentityReference.Value)'"
    }
}

# Apply or Update Rules for All Desired SIDs
$Inheritance = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit,ObjectInherit"
$Propagation = [System.Security.AccessControl.PropagationFlags]::None

foreach ($Entry in $DesiredPermissions.Values) {
    $TargetRule = New-Object System.Security.AccessControl.FileSystemAccessRule(
        $Entry.Sid,
        $Entry.Rights,
        $Inheritance,
        $Propagation,
        [System.Security.AccessControl.AccessControlType]::Allow
    )

    # Check if an exact single rule already matches and no conflicting rules exist for this SID
    $ExistingForSid = @($Acl.Access | Where-Object {
        -not $_.IsInherited -and
        $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value -eq $Entry.Sid.Value
    })

    $ExactMatch = $ExistingForSid.Count -eq 1 -and
                  $ExistingForSid[0].FileSystemRights -eq $TargetRule.FileSystemRights -and
                  $ExistingForSid[0].InheritanceFlags -eq $TargetRule.InheritanceFlags -and
                  $ExistingForSid[0].PropagationFlags -eq $TargetRule.PropagationFlags -and
                  $ExistingForSid[0].AccessControlType -eq "Allow"

    if (-not $ExactMatch) {
        # SetAccessRule replaces all existing rules for this SID with the exact desired rule
        $Acl.SetAccessRule($TargetRule)
        $AclModified = $true
        Write-Output "$Path - Set NTFS '$($Entry.Rights)' for '$($Entry.Name)'"
    } else {
        Write-Verbose "$Path - NTFS '$($Entry.Rights)' already configured for '$($Entry.Name)'"
    }
}

# 5. Commit ACL Changes Only If Modified
if ($AclModified) {
    Set-Acl -Path $Path -AclObject $Acl
    Write-Output "$Path - Successfully updated NTFS permission"
} else {
    Write-Verbose "$Path - No permission changes required"
}
