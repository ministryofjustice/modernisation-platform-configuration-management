function Get-ModPlatformADJoinCredential {

<#
.SYNOPSIS
    Retrieves a domain account credential that can be used for AD operations

.DESCRIPTION
    Using configuration returned from Get-ModPlatformADConfig, this function
    optionally assumes a role to access a secret containing the password of the
    domain join username. EC2 requires permissions to join the given role,
    a SSM parameter containing account IDs, and the aws cli.

.PARAMETER ModPlatformADConfig
    HashTable as returned from Get-ModPlatformADConfig function

.EXAMPLE
    $ADConfig = Get-ModPlatformADConfig
    $ADCredential = Get-ModPlatformADJoinCredential $ADConfig

.OUTPUTS
    PSCredentialObject
#>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][hashtable]$ModPlatformADConfig
  )

  $ErrorActionPreference = "Stop"

  $AccountIdsSSMParameterName = $ModPlatformADConfig.AccountIdsSSMParameterName
  $AccountIdsRaw = aws ssm get-parameter --name $AccountIdsSSMParameterName --with-decryption --query Parameter.Value --output text
  $AccountIds = "$AccountIdsRaw" | ConvertFrom-Json
  $SecretAccountId = $AccountIds.[string]$ModPlatformADConfig.SecretAccountName
  $SecretName = $ModPlatformADConfig.SecretName
  $SecretArn = "arn:aws:secretsmanager:eu-west-2:${SecretAccountId}:secret:${SecretName}"
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
    $SecretValueRaw = aws secretsmanager get-secret-value --secret-id "${SecretArn}" --query SecretString --output text
    $env:AWS_ACCESS_KEY_ID = $Tmp_AWS_ACCESS_KEY_ID
    $env:AWS_SECRET_ACCESS_KEY = $Tmp_AWS_SECRET_ACCESS_KEY
    $env:AWS_SESSION_TOKEN = $Tmp_AWS_SESSION_TOKEN
  } else {
    $SecretValueRaw = aws secretsmanager get-secret-value --secret-id "${SecretArn}" --query SecretString --output text
  }
  $SecretValue = "$SecretValueRaw" | ConvertFrom-Json
  $DomainNameNetbios = $ModPlatformADConfig.DomainNameNetbios
  $DomainJoinUsername = $ModPlatformADConfig.DomainJoinUsername
  $DomainJoinPassword = $SecretValue.$DomainJoinUsername
  if (-not $DomainJoinPassword) {
    Write-Error "Password secret ${SecretArn} does not contain domain join username ${DomainJoinUsername}"
  }
  $DomainJoinPasswordSecureString = ConvertTo-SecureString $SecretValue.$DomainJoinUsername -AsPlainText -Force
  New-Object System.Management.Automation.PSCredential ("$DomainNameNetbios\$DomainJoinUsername", $DomainJoinPasswordSecureString)
}

Export-ModuleMember -Function Get-ModPlatformADJoinCredential
