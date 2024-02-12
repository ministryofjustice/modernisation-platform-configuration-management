<#
.SYNOPSIS
    Get server-type tag and run associated UserDataScript
#>

$ErrorActionPreference = "Stop"
$Token = Invoke-RestMethod -TimeoutSec 2 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
$InstanceId = Invoke-RestMethod -TimeoutSec 2 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
$TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
$Tags = "$TagsRaw" | ConvertFrom-Json
$ServerTypeTag = ($Tags.Tags | Where-Object  {$_.Key -eq "server-type"}).Value
$ServerTypeTag = "HmppsDomainServicesTest"
$UserDataScript = "UserDataScripts/${ServerTypeTag}.ps1"

if (-not $ServerTypeTag) {
  Write-Error "Missing or blank server-type tag"
} elseif (-not (Get-ChildItem $UserDataScript -ErrorAction SilentlyContinue)) {
  Write-Error "Could not find $UserDataScript"
} else {
  . $UserDataScript
}
