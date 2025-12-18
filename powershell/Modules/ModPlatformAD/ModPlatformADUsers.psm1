function Get-ModPlatformADUserConfig {
<#
.SYNOPSIS
    Retrieve appropriate AD User config for the given Modernisation Platform environment.

.DESCRIPTION
    Either pass in the domain name as a parameter, or derive the AD configuration
    from EC2 tags (environment-name or domain-name).
    EC2 requires permissions to get tags and the aws cli.

.PARAMETER DomainNameFQDN
    Optionally specify the FQDN of the domain name to join

.EXAMPLE
    $ADUsers = Get-ModPlatformADUser my-fqdn-domain-name

.OUTPUTS
    HashTable
#>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][string]$DomainNameFQDN
  )

  $ModPlatformADUsers = @{
    "delius-mis-dev.internal" = @{
      SVC_DIS_NDL = @{
        Secret = "delius-mis-dev-sap-dis-passwords"
        Path   = "DC=Users"
        Groups = @(
          "AWS Delegated Administrators"
        )
        Options = @{
          Description           = "Service user for DIS Computer"
          CannotChangePassword  = $true
          PasswordNeverExpires  = $true
          ChangePasswordAtLogon = $false
        }
      }
    }
    "delius-mis-stage.internal" = @{
      SVC_DIS_NDL = @{
        Secret = "delius-mis-stage-sap-dis-passwords"
        Path   = "DC=Users"
        Groups = @(
          "AWS Delegated Administrators"
        )
        Options = @{
          Description           = "Service user for DIS Computer"
          CannotChangePassword  = $true
          PasswordNeverExpires  = $true
          ChangePasswordAtLogon = $false
        }
      }
    }
    "delius-mis-preprod.internal" = @{
      SVC_DIS_NDL = @{
        Secret = "delius-mis-preprod-sap-dis-passwords"
        Path   = "DC=Users"
        Groups = @(
          "AWS Delegated Administrators"
        )
        Options = @{
          Description           = "Service user for DIS Computer"
          CannotChangePassword  = $true
          PasswordNeverExpires  = $true
          ChangePasswordAtLogon = $false
        }
      }
    }
  }

  if ($ModPlatformADUsers.ContainsKey($DomainNameFQDN)) {
    $ConfigCopy = $ModPlatformADUsers[$DomainNameFQDN].Clone()
    Return $ConfigCopy
  } else {
    Write-Error "ERROR: DomainName $DomainNameFQDN user list not configured in code"
    Return $null
  }
}

function Get-ModPlatformADUserCredentials {
<#
.SYNOPSIS
    Retrieve passwords for Users from SecretsManager Secret

.DESCRIPTION
    For each user, retrieve password from secret and append to object
    EC2 requires permissions to get secrets and the aws cli.

.PARAMETER ModPlatformADUsers
    Output of Get-ModPlatformADUserConfig

.EXAMPLE
    Add-ModPlatformADUserCredentials $ADUsers
#>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][hashtable]$ModPlatformADUsers
  )

  $Secrets = @{}

  foreach ($User in $ModPlatformADUsers.GetEnumerator()) {
    if ($Secrets.ContainsKey($User.Value.Secret)) {
      $SecretValueRaw = $Secrets[$User.Value.Secret]
    } else {
      $SecretId = $User.Value.Secret
      $SecretValueRaw = aws secretsmanager get-secret-value --secret-id "${SecretId}" --query SecretString --output text
      $Secrets[$User.Value.Secret] = $SecretValueRaw
    }
    $Username = $User.Name
    $Password = $null
    try {
      $SecretJson = "$SecretValueRaw" | ConvertFrom-Json
      $Password = $SecretJson.$Username
    } catch {
      $Password = $SecretValueRaw
    }
    if ($Password) {
      $User.Value["Password"] = ConvertTo-SecureString $Password -AsPlainText -Force
    }
  }
}

function Add-ModPlatformADUsers {
<#
.SYNOPSIS
    Create/Modify AD User and add to AD Groups
#>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][hashtable]$ModPlatformADUsers,
    [Parameter(Mandatory=$true)][System.Management.Automation.PSCredential]$ModPlatformADCredential
  )

  $Groups = @{}

  foreach ($User in $ModPlatformADUsers.GetEnumerator()) {
    $Username = $User.Name
    $Options  = $User.Value.Options

    $ADUser = Get-ADUser -Filter 'Name -eq $Username' -Credential $ModPlatformADCredential

    if ($ADUser) {
      Write-Debug "Updating User: $Username"
      Set-ADUser -Identity $Username -Credential $ModPlatformADCredential @Options
    } elseif ($User.Value.ContainsKey("Password")) {
      $Password = $User.Value.Password
      Write-Output "Creating User: $Username"
      $ADUser = New-ADUser -Name $Username -Credential $ModPlatformADCredential -AccountPassword $Password -PassThru @Options
    } else {
      Write-Error "Cannot create user as no password found in secret: $Username"
    }
    if ($ADUser -and $User.Value.ContainsKey("Groups")) {
      foreach ($Group in $User.Value.Groups) {
        if (-not ($Groups.ContainsKey($Group))) {
          $Groups[$Group] = @()
        }
        $Groups[$Group] += $ADUser
      }
    }
  }

  foreach ($Group in $ModPlatformADGroups.GetEnumerator()) {
    $Groupname = $Group.Name
    $Users     = $Group.Value

    $ADGroup = Get-ADGroup -Filter 'Name -eq $Groupname' -Credential $ModPlatformADCredential

    if ($ADGroup) {
      $ADGroupMembers = Get-ADGroupMember -Identity $Groupname -Credential $ModPlatformADCredential

      foreach ($User in $Users) {
        $Username = $User.Name
        if ($ADGroupMembers | Where-Object { $_.distinguishedName -eq $User.DistinguishedName }) {
          Write-Debug "${Groupname}: $Username already a group member"
        } else {
          Write-Output "${Groupname}: Adding $Username to group"
          Add-ADGroupMember -Identity $Groupname -Members $User -Credential $ModPlatformADCredential
        }
      }
    } else {
      Write-Error "${Groupname}: Not adding $Username as group does not exist"
    }
  }
}

Export-ModuleMember -Function Get-ModPlatformADUserConfig
Export-ModuleMember -Function Get-ModPlatformADUserCredentials
Export-ModuleMember -Function Add-ModPlatformADUsers
