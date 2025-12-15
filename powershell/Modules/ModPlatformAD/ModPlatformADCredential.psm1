function Get-ModPlatformADSecret {

<#
.SYNOPSIS
    Retrieves domain account secret from SecretsManager

.DESCRIPTION
    Using configuration returned from Get-ModPlatformADConfig, this function
    optionally assumes a role to access a SecretsManager secret containing
    domain secrets. EC2 requires permissions to join the given role,
    a SSM parameter containing account IDs, and the aws cli.

.PARAMETER ModPlatformADConfig
    HashTable as returned from Get-ModPlatformADConfig function

.EXAMPLE
    $ADConfig = Get-ModPlatformADConfig
    $ADSecret = Get-ModPlatformADJoinCredential $ADConfig
    $Password = ConvertTo-SecureString $ADSecret.svc_join_domain

.OUTPUTS
    PSCustomObject
#>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][hashtable]$ModPlatformADConfig
  )

  $ErrorActionPreference = "Stop"

  $AccountIdsRaw = "{}"
  if ($ModPlatformADConfig.ContainsKey("AccountIdsSSMParameterName")) {
    $AccountIdsSSMParameterName = $ModPlatformADConfig.AccountIdsSSMParameterName
    $AccountIdsRaw = aws ssm get-parameter --name $AccountIdsSSMParameterName --with-decryption --query Parameter.Value --output text
  }
  $AccountIds = "$AccountIdsRaw" | ConvertFrom-Json

  $SecretName = $ModPlatformADConfig.SecretName
  $SecretId   = $SecretName
  if ($ModPlatformADConfig.ContainsKey("SecretAccountName")) {
    $SecretAccountId = $AccountIds.[string]$ModPlatformADConfig.SecretAccountName
    $SecretId        = "arn:aws:secretsmanager:eu-west-2:${SecretAccountId}:secret:${SecretName}"
  }

  $SecretRoleName = $null
  if ($ModPlatformADConfig.ContainsKey("SecretRoleName")) {
    $SecretRoleName = $ModPlatformADConfig.SecretRoleName
  }
  if ($SecretRoleName) {
    $AccountId = aws sts get-caller-identity --query Account --output text
    $SecretRoleName = $ModPlatformADConfig.SecretRoleName
    $RoleArn = "arn:aws:iam::${AccountId}:role/${SecretRoleName}"
    $Session = "ModPlatformADConfig-$env:COMPUTERNAME"
    $CredsRaw = aws sts assume-role --role-arn "${RoleArn}" --role-session-name "${Session}"
    $Creds = "$CredsRaw" | ConvertFrom-Json
    $Tmp_AWS_ACCESS_KEY_ID = $env:AWS_ACCESS_KEY_ID
    $Tmp_AWS_SECRET_ACCESS_KEY = $env:AWS_SECRET_ACCESS_KEY
    $Tmp_AWS_SESSION_TOKEN = $env:AWS_SESSION_TOKEN
    $env:AWS_ACCESS_KEY_ID = $Creds.Credentials.AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $Creds.Credentials.SecretAccessKey
    $env:AWS_SESSION_TOKEN = $Creds.Credentials.SessionToken
    $SecretValueRaw = aws secretsmanager get-secret-value --secret-id "${SecretId}" --query SecretString --output text
    $env:AWS_ACCESS_KEY_ID = $Tmp_AWS_ACCESS_KEY_ID
    $env:AWS_SECRET_ACCESS_KEY = $Tmp_AWS_SECRET_ACCESS_KEY
    $env:AWS_SESSION_TOKEN = $Tmp_AWS_SESSION_TOKEN
  } else {
    $SecretValueRaw = aws secretsmanager get-secret-value --secret-id "${SecretId}" --query SecretString --output text
  }
  if ($SecretValueRaw[0] != '{') {
    "$SecretValueRaw" | ConvertFrom-Json
  } else {
  }
}

function Get-ModPlatformADJoinCredential {

<#
.SYNOPSIS
    Retrieves credential that can be used for joining Computers to the domain

.DESCRIPTION
    Using configuration returned from Get-ModPlatformADConfig, this function
    optionally assumes a role to access a secret containing the password of the
    domain join username. EC2 requires permissions to join the given role,
    a SSM parameter containing account IDs, and the aws cli.

.PARAMETER ModPlatformADConfig
    HashTable as returned from Get-ModPlatformADConfig function

.PARAMETER ModPlatformADSecret
    Optional PSCustomObject containing secrets as returned from Get-ModPlatformADSecret

.EXAMPLE
    $ADConfig = Get-ModPlatformADConfig
    $ADCredential = Get-ModPlatformADJoinCredential $ADConfig

.OUTPUTS
    PSCredentialObject
#>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][hashtable]$ModPlatformADConfig,
    [PSCustomObject]$ModPlatformADSecret
  )

  $ErrorActionPreference = "Stop"

  if ($ModPlatformADSecret -eq $null) {
    $ModPlatformADSecret = Get-ModPlatformADSecret -ModPlatformADConfig $ModPlatformADConfig
  }
  $DomainNameNetbios = $ModPlatformADConfig.DomainNameNetbios
  $DomainJoinUsername = $ModPlatformADConfig.DomainJoinUsername
  $DomainJoinPassword = $ModPlatformADSecret.$DomainJoinUsername
  if (-not $DomainJoinPassword) {
    Write-Error "Password secret does not contain domain join username ${DomainJoinUsername}"
  }
  $DomainJoinPasswordSecureString = ConvertTo-SecureString $DomainJoinPassword -AsPlainText -Force
  New-Object System.Management.Automation.PSCredential ("$DomainNameNetbios\$DomainJoinUsername", $DomainJoinPasswordSecureString)
}

function Get-ModPlatformADAdminCredential {

<#
.SYNOPSIS
    Retrieves credential that can be used for administrating the domain

.DESCRIPTION
    Using configuration returned from Get-ModPlatformADConfig, this function
    optionally assumes a role to access a secret containing the password of the
    domain join username. EC2 requires permissions to join the given role,
    a SSM parameter containing account IDs, and the aws cli.

.PARAMETER ModPlatformADConfig
    HashTable as returned from Get-ModPlatformADConfig function

.PARAMETER ModPlatformADSecret
    Optional PSCustomObject containing secrets as returned from Get-ModPlatformADSecret

.EXAMPLE
    $ADConfig = Get-ModPlatformADConfig
    $ADCredential = Get-ModPlatformADAdminCredential $ADConfig

.OUTPUTS
    PSCredentialObject
#>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][hashtable]$ModPlatformADConfig,
    [PSCustomObject]$ModPlatformADSecret
  )

  $ErrorActionPreference = "Stop"

  if ($ModPlatformADSecret -eq $null) {
    $ModPlatformADSecret = Get-ModPlatformADSecret -ModPlatformADConfig $ModPlatformADConfig
  }
  $DomainNameNetbios = $ModPlatformADConfig.DomainNameNetbios
  $DomainAdminUsername = $ModPlatformADConfig.DomainAdminUsername
  $DomainAdminPassword = $ModPlatformADSecret.$DomainAdminUsername
  if (-not $DomainAdminPassword) {
    Write-Error "Password secret does not contain domain admin username ${DomainAdminUsername}"
  }
  $DomainAdminPasswordSecureString = ConvertTo-SecureString $DomainAdminPassword -AsPlainText -Force
  New-Object System.Management.Automation.PSCredential ("$DomainNameNetbios\$DomainAdminUsername", $DomainAdminPasswordSecureString)
}

function Get-ModPlatformADSafeModeAdministratorPassword {

<#
.SYNOPSIS
    Retrieves credential that can be used for administrating the domain

.DESCRIPTION
    Using configuration returned from Get-ModPlatformADConfig, this function
    optionally assumes a role to access a secret containing the password of the
    domain join username. EC2 requires permissions to join the given role,
    a SSM parameter containing account IDs, and the aws cli.

.PARAMETER ModPlatformADConfig
    HashTable as returned from Get-ModPlatformADConfig function

.PARAMETER ModPlatformADSecret
    Optional PSCustomObject containing secrets as returned from Get-ModPlatformADSecret

.EXAMPLE
    $ADConfig = Get-ModPlatformADConfig
    $ADCredential = Get-ModPlatformADSafeModeAdministratorPassword $ADConfig

.OUTPUTS
    Secure-String
#>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][hashtable]$ModPlatformADConfig,
    [PSCustomObject]$ModPlatformADSecret
  )

  $ErrorActionPreference = "Stop"

  if ($ModPlatformADSecret -eq $null) {
    $ModPlatformADSecret = Get-ModPlatformADSecret -ModPlatformADConfig $ModPlatformADConfig
  }
  $DomainNameNetbios = $ModPlatformADConfig.DomainNameNetbios
  $DomainAdminUsername = $ModPlatformADConfig.DomainAdminUsername
  $SafeModeAdministratorPassword = $ModPlatformADSecret.SafeModeAdministratorPassword
  if (-not $SafeModeAdministratorPassword) {
    Write-Error "Password secret does not contain domain admin username ${SafeModeAdministratorPassword}"
  }
  ConvertTo-SecureString $SafeModeAdministratorPassword -AsPlainText -Force
}

Export-ModuleMember -Function Get-ModPlatformADSecret
Export-ModuleMember -Function Get-ModPlatformADJoinCredential
Export-ModuleMember -Function Get-ModPlatformADAdminCredential
Export-ModuleMember -Function Get-ModPlatformADSafeModeAdministratorPassword
