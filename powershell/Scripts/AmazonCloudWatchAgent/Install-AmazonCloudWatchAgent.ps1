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
$CloudWatchInstallUrl = "https://amazoncloudwatch-agent.s3.amazonaws.com/windows/amd64/latest/amazon-cloudwatch-agent.msi"
$CloudWatchInstallEtagPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "amazon-cloudwatch-agent.msi.etag.json"

# Avoid re-downloading the install file each time script is run. Record ETag of the file.
$InstallAmazonCloudWatchAgent = $false
$CloudWatchInstallEtag = (Invoke-WebRequest $CloudWatchInstallUrl -Method Head -UseBasicParsing).Headers.ETag
if (!(Test-Path $CloudWatchCtlPath)) {
  Write-Output "AmazonCloudWatchAgent not found, installing latest version."
  $InstallAmazonCloudWatchAgent = $true
} elseif ($UpdateAgent) {
  $CloudWatchInstallLastEtag = "NONE"
  if (Test-Path $CloudWatchInstallEtagPath) {
    $CloudWatchInstallLastEtag = Get-Content -Path $CloudWatchInstallEtagPath
  }
  if ($CloudWatchInstallLastEtag -ne $CloudWatchInstallEtag) {
    Write-Output "Existing AmazonCloudWatchAgent installation outdated, installing latest version."
    $InstallAmazonCloudWatchAgent = $true
  } else {
    Write-Verbose "AmazonCloudWatchAgent already installed at latest version."
  }
}

if ($InstallAmazonCloudWatchAgent) {
  if ($WhatIfPreference) {
    Write-Output "What-If: Downloading agent from $CloudWatchInstallUrl"
  } else {
    Stop-Service AmazonCloudWatchAgent -ErrorAction SilentlyContinue

    $LocalMsiPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "amazon-cloudwatch-agent.msi"
    Invoke-WebRequest $CloudWatchInstallUrl -OutFile $LocalMsiPath -UseBasicParsing
    $accessResult = Test-FileAccessibility -FilePath $LocalMsiPath
    if ($accessResult) {
      Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$LocalMsiPath`" /quiet /norestart" -Wait
    }
    Remove-ItemWithRetry -Path $LocalMsiPath
    $CloudWatchInstallEtag | Out-File $CloudWatchInstallEtagPath
  }
}

# Use SSM parameter if configured, otherwise fall back and use file from repo
# NOTE: this assumes relevant AWS powershell modules are installed. This may fail on older OS
$CustomConfig = (Get-SSMParameterValue -Names "cloud-watch-config-windows" -WithDecryption $True)
if ($CustomConfig.Parameters) {
  $ExistingConfigPath = "C:\ProgramData\Amazon\AmazonCloudWatchAgent\Configs\ssm_cloud-watch-config-windows"
  $ConfigPath = Split-Path $ExistingConfigPath
  $VersionMarker = "$ConfigPath\version.txt"
  $CurrentVersion = "NONE"
  $NewVersion = $CustomConfig.Parameters[0].Version
  if (Test-Path -Path $VersionMarker) {
    $CurrentVersion = Get-Content -Path $VersionMarker
  }
  if ($CurrentVersion -eq $NewVersion) {
    Write-Verbose "AmazonCloudWatchAgent config from SSM parameter cloud-watch-config-windows is up to date, version=$CurrentVersion"
  } else {
    Write-Output "Updating AmazonCloudWatchAgent config from SSM parameter cloud-watch-config-windows, version $CurrentVersion -> $NewVersion"

    if ($WhatIfPreference) {
      Write-Output "What-If: $CloudWatchCtlPath -m ec2 -a fetch-config -c ssm:cloud-watch-config-windows -s"
    } else {
      . $CloudWatchCtlPath -m ec2 -a fetch-config -c ssm:cloud-watch-config-windows -s
      Set-Content -Path "$VersionMarker" -Value $NewVersion -Force
    }
  }
} else {
  $NewConfigPath = Join-Path -Path "../../Configs/AmazonCloudWatchAgent" -ChildPath $ConfigFilename
  $ExistingConfigPath = "C:\ProgramData\Amazon\AmazonCloudWatchAgent\Configs\file_default.json"
  if (!(Test-Path $NewConfigPath)) {
    Write-Error "AmazonCloudWatchAgent baseline config not found in location: $NewConfigPath"
  }
  $CurrentVersion = "NONE"
  if ($WhatIfPreference) {
    $NewVersion = "CannotDetermineUnderWhatIf"
  } else {
    $NewVersion = (Get-FileHash $NewConfigPath).Hash
    if (Test-Path $ExistingConfigPath) {
      $CurrentVersion = (Get-FileHash $ExistingConfigPath).Hash
    }
  }
  if ($CurrentVersion -eq $NewVersion) {
    Write-Verbose "AmazonCloudWatchAgent config from git repo is up to date, hash=$CurrentVersion"
  } else {
    Write-Output "Updating AmazonCloudWatchAgent config from git repo, hash $CurrentVersion -> $NewVersion"

    if ($WhatIfPreference) {
      Write-Output "What-If: $CloudWatchCtlPath -m ec2 -a fetch-config -c file:$NewConfigPath -s"
    } else {
      . $CloudWatchCtlPath -m ec2 -a fetch-config -c file:$NewConfigPath -s
    }
  }
}
