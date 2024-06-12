<#
.SYNOPSIS
    Install, optionally upgrade, and configure AmazonCloudWatchAgent

.DESCRIPTION
    Install latest version of AmazonCloudWatchAgent and configure with the supplied config.

.PARAMETER ConfigFilename
    The config filename to use from  ../../Configs/AmazonCloudWatchAgent, by default default.json

.PARAMETER UpdateAgent
    Update the agent if set to $true and there has been an update

.EXAMPLE
    Add-AmazonCloudWatchAgent
#>

[CmdletBinding()]
param (
  [string]$ConfigFilename = "default.json",
  [bool]$UpdateAgent = $true
)

$CloudWatchCtlPath="C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1"
$ExistingConfigPath="C:\ProgramData\Amazon\AmazonCloudWatchAgent\Configs\file_default.json"
$CloudWatchInstallUrl="https://amazoncloudwatch-agent.s3.amazonaws.com/windows/amd64/latest/amazon-cloudwatch-agent.msi"
$NewConfigPath=Join-Path -Path "../../Configs/AmazonCloudWatchAgent" -ChildPath $ConfigFilename
$CloudWatchInstallEtagPath=Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "amazon-cloudwatch-agent.msi.etag.json"

if (!(Test-Path $NewConfigPath)) {
  Write-Error "AmazonCloudWatchAgent config not found $NewConfigPath"
}

# Avoid re-downloading the install file each time script is run. Record ETag of the file.
$CloudWatchInstallEtag=(Invoke-WebRequest $CloudWatchInstallUrl -Method Head -UseBasicParsing).Headers.ETag
if (!(Test-Path $CloudWatchCtlPath)) {
  Write-Output "Installing AmazonCloudWatchAgent"
  $LocalMsiPath=Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "amazon-cloudwatch-agent.msi"
  Invoke-WebRequest $CloudWatchInstallUrl -OutFile $LocalMsiPath -UseBasicParsing
  msiexec /i $LocalMsiPath /quiet
  Remove-Item $LocalMsiPath
  $CloudWatchInstallEtag | Out-File $CloudWatchInstallEtagPath
} elseif ($UpdateAgent) {
  $CloudWatchInstallLastEtag="NONE"
  if (Test-Path $CloudWatchInstallEtagPath) {
    $CloudWatchInstallLastEtag=Get-Content -Path $CloudWatchInstallEtagPath
  }
  if ($CloudWatchInstallLastEtag -ne $CloudWatchInstallEtag) {
    Write-Output "Upgrading AmazonCloudWatchAgent"
    $LocalMsiPath=Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "amazon-cloudwatch-agent.msi"
    Invoke-WebRequest $CloudWatchInstallUrl -OutFile $LocalMsiPath -UseBasicParsing
    Stop-Service AmazonCloudWatchAgent
    msiexec /i $LocalMsiPath /quiet
    Remove-Item $LocalMsiPath
    $CloudWatchInstallEtag | Out-File $CloudWatchInstallEtagPath
  }
}

# Check if cloudwatch already configured. Only update if there's been a change.
if (Test-Path $ExistingConfigPath) {
  if ((Get-FileHash $NewConfigPath).Hash -ne ((Get-FileHash $ExistingConfigPath).Hash)) {
    Write-Output "Updating AmazonCloudWatchAgent Config"
    . $CloudWatchCtlPath -m ec2 -a fetch-config -c file:$NewConfigPath -s
  } else {
    $StatusRaw=. $CloudwatchCtlPath -m ec2 -a status
    $Status="$StatusRaw" | ConvertFrom-Json
    if ($Status.status -ne "running") {
      Write-Output "Starting AmazonCloudWatchAgent"
      . $CloudwatchCtlPath -m ec2 -a start
    } else {
      Write-Output "AmazonCloudWatchAgent already running and configured"
    }
  }
} else {
  Write-Output "Configuring AmazonCloudWatchAgent"
  . $CloudWatchCtlPath -m ec2 -a fetch-config -c file:$NewConfigPath -s
}
