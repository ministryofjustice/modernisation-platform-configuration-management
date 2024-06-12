<#
.SYNOPSIS
    Install and configure AmazonCloudWatchAgent

.DESCRIPTION
    By default the script derives the hostname from the Name tag. Or specify NewHostname parameter.
    By default derives the AD configuration from EC2 tags (environment-name or domain-name), or specify DomainNameFQDN parameter.
    EC2 requires permissions to get tags and the aws cli.
    Exits with 3010 if reboot required and script requires re-running. For use in SSM docs

.PARAMETER ConfigFilename
    Override default config to use from  ../../Configs/AmazonCloudWatchAgent 

.PARAMETER UpdateAgent
    Update the agent if it is already installed

.EXAMPLE
    Add-AmazonCloudWatchAgent
#>

[CmdletBinding()]
param (
  [string]$ConfigFilename = "default.json",
  [string]$UpdateAgent = $false,
)

$CloudWatchCtlPath="C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1"
$CloudWatchInstallUrl="https://amazoncloudwatch-agent.s3.amazonaws.com/windows/amd64/latest/amazon-cloudwatch-agent.msi"
$ConfigPath=Join-Path -Path ../../Configs/AmazonCloudWatchAgentConfig -ChildPath $ConfigFilename

if (!Test-Path $ConfigPath)) {
  Write-Error "AmazonCloudWatchAgent not found $ConfigPath"
}

if (!(Test-Path $CloudWatchCtlPath)) {
  Write-Output "Installing AmazonCloudWatchAgent"
  $LocalMsiPath=Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "amazon-cloudwatch-agent.msi"
  Invoke-WebRequest $CloudWatchInstallUrl -OutFile $LocalMsiPath
  msiexec /i $LocalMsiPath /quiet
  Remove-Item $LocalMsiPath
} elif ($UpdateAgent) {
  Write-Output "Upgrading AmazonCloudWatchAgent"
  $LocalMsiPath=Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "amazon-cloudwatch-agent.msi"
  Invoke-WebRequest $CloudWatchInstallUrl -OutFile $LocalMsiPath
  msiexec /i $LocalMsiPath /quiet
  Remove-Item $LocalMsiPath
}

#Write-Output "Configuring AmazonCloudWatchAgent"
#$ApplyConfig=. $CloudWatchCtlPath -m ec2 -c file:../../Configs/AmazonCloudWatchAgentConfig.json -s
#$StatusRaw=. $CloudwatchCtlPath -m ec2 -a status
#$Status="$StatusRaw" | ConvertFrom-Json
#Write-Output "Status $Status"
