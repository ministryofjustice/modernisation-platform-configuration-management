# Copy tnsnames.ora from Configs/Oracle/Tns/env/tnsnames.ora[.Name]
# e.g.
# Configs/Oracle/Tns/oracle-national-reporting-test/tnsnames.ora
# Configs/Oracle/Tns/delius-mis-preproduction/tnsnames.ora.delius-mis-dis-1

function Get-Tags {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  return $Tags
}

function Get-SourceTnsOraPath {
  $Tags = Get-Tags
  $EnvironmentNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "environment-name"}).Value
  $NameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "Name"}).Value

  $SourceTnsOraBasePath = Join-Path $PSScriptRoot         -ChildPath "..\..\Configs\Oracle\Tns"
  $SourceTnsOraEnvPath  = Join-Path $SourceTnsOraBasePath -ChildPath $EnvironmentNameTag
  $SourceTnsOraPath     = Join-Path $SourceTnsOraEnvPath  -ChildPath ("tnsnames.ora." + $NameTag)

  if (-not (Test-Path $SourceTnsOraPath)) {
    $SourceTnsOraPath = Join-Path $SourceTnsOraEnvPath -ChildPath "tnsnames.ora"
    if (-not (Test-Path $SourceTnsOraPath)) {
      Write-Error ("Source tnsnames.ora or " + ("tnsnames.ora." + $NameTag) + " not found in $SourceTnsOraPath")    
    }
  }
  Return $SourceTnsOraPath
}

function Get-TargetTnsOraPath {
  $OracleHome = $env:ORACLE_HOME
  if (-Not $OracleHome) {
    $OracleHome = 'C:\app\oracle\product\19.0.0\client_1'
  }
  $TargetTnsOraBasePath = Join-Path $OracleHome -ChildPath 'network\admin'
  $TargetTnsOraPath = Join-Path $TargetTnsOraBasePath -ChildPath 'tnsnames.ora'
  if (-Not (Test-Path $TargetTnsOraBasePath)) {
    Write-Error "Oracle client not found at $TargetTnsOraBasePath, please install first"
  }
  Return $TargetTnsOraPath
}

function Copy-TargetTnsOraPath {
  [CmdletBinding()]
  param (
    [string]$SourceTnsOraPath,
    [string]$TargetTnsOraPath
  )
  if (-Not (Test-Path $TargetTnsOraPath)) {
    Write-Output "TNS config: Creating $TargetTnsOraPath"
    Copy-Item -Path $SourceTnsOraPath -Destination $TargetTnsOraPath -Force
  } elseif ((Get-FileHash $SourceTnsOraPath).Hash -ne (Get-FileHash $TargetTnsOraPath).Hash) {
    Write-Output "TNS config: Updating $TargetTnsOraPath"
    Copy-Item -Path $TargetTnsOraPath -Destination (Join-Path $TargetTnsOraPath -ChildPath ".backup") -Force
    Copy-Item -Path $SourceTnsOraPath -Destination $TargetTnsOraPath -Force
  } else {
    Write-Output "TNS config: Already up to date $TargetTnsOraPath"
  }
}

$ErrorActionPreference = "Stop"
$SourceTnsOraPath = Get-SourceTnsOraPath
$TargetTnsOraPath = Get-TargetTnsOraPath
Copy-TargetTnsOraPath $SourceTnsOraPath $TargetTnsOraPath
