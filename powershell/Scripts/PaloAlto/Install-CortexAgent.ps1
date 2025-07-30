<#
.SYNOPSIS
    Install Cortex Windows Agent

.EXAMPLE
    Install-CortexAgent.ps1
#>


[CmdletBinding()]
param (
  [string]$ConfigName
)

$ConfigByEnvironmentNameTag = @{
  "nomis-preproduction" = @{
    "CortexAgentS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
    "CortexAgentS3Folder" = "hmpps/XSIAM/Agents/nomis"
    "CortexAgentMsi"      = "nomis_windows_8_8_0_10622_x64.msi"
  }
  "nomis-production" = @{
    "CortexAgentS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
    "CortexAgentS3Folder" = "hmpps/XSIAM/Agents/nomis"
    "CortexAgentMsi"      = "nomis_windows_8_8_0_10622_x64.msi"
  }
}

function Get-EnvironmentNameTag {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $EnvironmentNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "environment-name"}).Value

  Return $EnvironmentNameTag
}

$ErrorActionPreference = "Stop"

if (-not $ConfigName) {
  $ConfigName = Get-EnvironmentNameTag
}

if (-not $ConfigByEnvironmentNameTag.Contains($ConfigName)) {
  Write-Output "Skipping Cortex Agent installation as no configuration found for $ConfigName"
} elseif (Test-Path "C:/Program Files/Palo Alto Networks/Traps/CyveraConsole.exe") {
  Write-Output "Cortex Agent already installed"
} else {
  Write-Output "Getting Cortex Agent location for $ConfigName"
  $Config = $ConfigByEnvironmentNameTag[$ConfigName]
  $CortexAgentS3Bucket = $Config["CortexAgentS3Bucket"]
  $CortexAgentS3Folder = $Config["CortexAgentS3Folder"]
  $CortexAgentMsi      = $Config["CortexAgentMsi"]
  Set-Location -Path ([System.IO.Path]::GetTempPath())
  $LocalMsiPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $CortexAgentMsi
  Write-Output "Downloading Cortex Agent: $CortexAgentS3Bucket $CortexAgentS3Folder $CortexAgentMsi"
  if ($WhatIfPreference) {
    Write-Output "What-If: Read-S3Object -BucketName $CortexAgentS3Bucket -Key $CortexAgentS3Folder/$CortexAgentMsi -File .\$CortexAgentMsi"
    Write-Output "What-If: Start-Process -FilePath msiexec.exe -ArgumentList /i $LocalMsiPath /quiet /norestart -Wait"
  } else {
    Read-S3Object -BucketName $CortexAgentS3Bucket -Key "$CortexAgentS3Folder/$CortexAgentMsi" -File ".\$CortexAgentMsi" | Out-Null
    Write-Output "Installing CortexAgent"
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$LocalMsiPath`" /quiet /norestart" -Wait
  }
}
