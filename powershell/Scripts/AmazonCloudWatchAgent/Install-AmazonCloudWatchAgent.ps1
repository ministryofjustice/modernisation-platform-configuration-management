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

function Remove-ItemWithRetry {
  param (
    [string]$Path,
    [int]$MaxRetries = 4,
    [int]$DelaySeconds = 3
  )

  $retryCount = 0
  $success = $false

  while ($retryCount -lt $MaxRetries -and -not $success) {
    try {
      $retryCount++
      Remove-Item -Path $Path -ErrorAction Stop -Force
      $success = $true
      Write-Output "$Path removed successfully on attempt $retryCount."
    }
    catch {
      Write-Output "Attempting to remove $Path on attempt $retryCount failed. Retrying in $DelaySeconds seconds..."
      Start-Sleep -Seconds $DelaySeconds
    }
  }

  if (-not $success) {
    Write-Output "Failed to remove $Path after $MaxRetries attempts."
  }
}

function Test-FileAccessibility {
  param (
    [string]$FilePath,
    [int]$MaxRetries = 4,
    [int]$DelaySeconds = 3
  )

  $retryCount = 0
  $success = $false

  while ($retryCount -lt $MaxRetries -and -not $success) {
    try {
      $retryCount++
      # Attempt to open the file for reading
      $fileStream = [System.IO.File]::Open($FilePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::None)
      $fileStream.Close()
      $success = $true
      Write-Output "File $FilePath is accessible, on $retryCount attempt, we can proceed with installation."
    }
    catch {
      Write-Output "Attempt $retryCount File is not accessible. Retrying in $DelaySeconds seconds..."
      Start-Sleep -Seconds $
    }
  }

  if (-not $success) {
    Write-Output "Failed to access $FilePath after $MaxRetries attempts at $DelaySeconds second intervals."
  }
  return $success
}


$CloudWatchCtlPath = "C:\Program Files\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1"
$ExistingConfigPath = "C:\ProgramData\Amazon\AmazonCloudWatchAgent\Configs\file_default.json"
$CloudWatchInstallUrl = "https://amazoncloudwatch-agent.s3.amazonaws.com/windows/amd64/latest/amazon-cloudwatch-agent.msi"
$NewConfigPath = Join-Path -Path "../../Configs/AmazonCloudWatchAgent" -ChildPath $ConfigFilename
$CloudWatchInstallEtagPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "amazon-cloudwatch-agent.msi.etag.json"

if (!(Test-Path $NewConfigPath)) {
  Write-Error "AmazonCloudWatchAgent baseline config not found in location: $NewConfigPath"
}

# Avoid re-downloading the install file each time script is run. Record ETag of the file.
$CloudWatchInstallEtag = (Invoke-WebRequest $CloudWatchInstallUrl -Method Head -UseBasicParsing).Headers.ETag
if (!(Test-Path $CloudWatchCtlPath)) {
  Write-Output "Existing AmazonCloudWatchAgent installation not found, installing latest version."
  $LocalMsiPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "amazon-cloudwatch-agent.msi"
  Invoke-WebRequest $CloudWatchInstallUrl -OutFile $LocalMsiPath -UseBasicParsing

  $accessResult = Test-FileAccessibility -FilePath $LocalMsiPath
  if ($accessResult) {
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$LocalMsiPath`" /quiet /norestart" -Wait
  }

  Remove-ItemWithRetry -Path $LocalMsiPath
  $CloudWatchInstallEtag | Out-File $CloudWatchInstallEtagPath
}
elseif ($UpdateAgent) {
  $CloudWatchInstallLastEtag = "NONE"
  if (Test-Path $CloudWatchInstallEtagPath) {
    $CloudWatchInstallLastEtag = Get-Content -Path $CloudWatchInstallEtagPath
  }
  if ($CloudWatchInstallLastEtag -ne $CloudWatchInstallEtag) {
    Write-Output "Existing AmazonCloudWatchAgent installation outdated, installing latest version."
    $LocalMsiPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "amazon-cloudwatch-agent.msi"
    Invoke-WebRequest $CloudWatchInstallUrl -OutFile $LocalMsiPath -UseBasicParsing
    Stop-Service AmazonCloudWatchAgent
    $accessResult = Test-FileAccessibility -FilePath $LocalMsiPath
    if ($accessResult) {
      Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$LocalMsiPath`" /quiet /norestart" -Wait
    }
    Remove-ItemWithRetry -Path $LocalMsiPath
    $CloudWatchInstallEtag | Out-File $CloudWatchInstallEtagPath
  }
}

# Check if cloudwatch already configured on a custom (account specific) config, only update if there's been a change.
$CustomConfig = (Get-SSMParameterValue -Names "cloud-watch-config-windows" -WithDecryption $True)
if ($null -eq $CustomConfig.Parameters.Value) { write-output "Account specific CustomConfig not configured, using baseline." }
else {
  $ExistingConfigPath = "C:\ProgramData\Amazon\AmazonCloudWatchAgent\Configs\ssm_cloud-watch-config-windows"
  $ConfigPath = split-path $ExistingConfigPath
  $VersionMarker = "$ConfigPath\version.txt"
  if (Test-Path -Path $VersionMarker) {
    If ((Get-Content -Path $VersionMarker) -eq $CustomConfig.Parameters[0].Version) {
      Write-Output "Custom config is at current version"  $CustomConfig.Parameters[0].Version
    }
    Else {
      Write-Output "Custom config version is NOT current version, updating."
      Write-Output "Updating AmazonCloudWatchAgent Config Using SSM Parameter Version:" $CustomConfig.Parameters[0].Version
      . $CloudWatchCtlPath -m ec2 -a fetch-config -c ssm:cloud-watch-config-windows -s

      Set-Content -Path "$VersionMarker" -Value $CustomConfig.Parameters[0].Version -Force
    }
  }
  else {
    Write-Output "File does not exist: $VersionMarker, assuming an update is required."
    Write-Output "Updating AmazonCloudWatchAgent Config Using SSM Parameter Version:" $CustomConfig.Parameters[0].Version
    . $CloudWatchCtlPath -m ec2 -a fetch-config -c ssm:cloud-watch-config-windows -s
    Set-Content -Path "$VersionMarker" -Value $CustomConfig.Parameters[0].Version -Force
  }
}

# Check if cloudwatch already configured on default config, only update if there's been a change.
if ($null -eq $CustomConfig.Parameters.Value) {
  if (Test-Path $ExistingConfigPath) {
    if ((Get-FileHash $NewConfigPath).Hash -ne ((Get-FileHash $ExistingConfigPath).Hash)) {
      Write-Output "Updating AmazonCloudWatchAgent Config"
      . $CloudWatchCtlPath -m ec2 -a fetch-config -c file:$NewConfigPath -s
    }
    else {
      $StatusRaw = . $CloudwatchCtlPath -m ec2 -a status
      $Status = "$StatusRaw" | ConvertFrom-Json
      if ($Status.status -ne "running") {
        Write-Output "Starting AmazonCloudWatchAgent"
        . $CloudwatchCtlPath -m ec2 -a start
      }
      else {
        Write-Output "AmazonCloudWatchAgent already running and configured"
      }
    }
  }
  else {
    Write-Output "Configuring AmazonCloudWatchAgent"
    . $CloudWatchCtlPath -m ec2 -a fetch-config -c file:$NewConfigPath -s
  }
}
