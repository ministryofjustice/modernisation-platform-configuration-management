<#
.SYNOPSIS
    Configure Smb Shares

.DESCRIPTION
    By default derives the configuration from the EC2 Name tag
    EC2 requires permissions to get tags and the aws cli.
#>

$GlobalConfig = @{
  "delius-mis-dev-dis-1" = @{
    "Path"             = "D:\LMIS"
    "ShareName"        = "LMIS"
    "FullControlUsers" = @("BUILTIN\Administrators", "NT AUTHORITY\SYSTEM", "delius-mis-dev\SVC_DIS_NDL")
    "ModifyUsers"      = @()
    "ReadOnlyUsers"    = @()
  }
  "delius-mis-stage-dis-1" = @{
    "Path"             = "D:\LMIS"
    "ShareName"        = "LMIS"
    "FullControlUsers" = @("BUILTIN\Administrators", "NT AUTHORITY\SYSTEM", "delius-mis-stage\SVC_DIS_NDL")
    "ModifyUsers"      = @()
    "ReadOnlyUsers"    = @()
  }
  "delius-mis-preprod-dis-1"= @{
    "Path"             = "D:\LMIS"
    "ShareName"        = "LMIS"
    "FullControlUsers" = @("BUILTIN\Administrators", "NT AUTHORITY\SYSTEM", "delius-mis-preprod\SVC_DIS_NDL")
    "ModifyUsers"      = @()
    "ReadOnlyUsers"    = @()
  }
  "delius-mis-prod-dis-1"= @{
    "Path"             = "D:\LMIS"
    "ShareName"        = "LMIS"
    "FullControlUsers" = @("BUILTIN\Administrators", "NT AUTHORITY\SYSTEM", "delius-mis-prod\SVC_DIS_NDL")
    "ModifyUsers"      = @()
    "ReadOnlyUsers"    = @()
  }
}

function Get-Config {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = 3600 } -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token } -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $NameTag = ($Tags.Tags | Where-Object { $_.Key -eq "Name" }).Value

  if (-not $GlobalConfig.Contains($NameTag)) {
    Write-Error "Unexpected Name tag value $NameTag"
  }
  Return $GlobalConfig[$NameTag]
}

$Config = Get-Config

. ../Common/Add-SmbShare.ps1 -Path $Config.Path -ShareName $Config.ShareName
. ../Common/Set-SmbSharePermissions.ps1 -Path $Config.Path -FullControlUsers $Config.FullControlUsers -ModifyUsers $Config.ModifyUsers -ReadOnlyUsers $Config.ReadOnlyUsers
