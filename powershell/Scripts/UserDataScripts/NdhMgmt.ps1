$GlobalConfig = @{
  "all" = @{
    "SQLDeveloperS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
    "SQLDeveloperS3Folder" = "hmpps/sqldeveloper"
    "apps = @(
      "firefox",
      "libreoffice-still",
      "notepadplusplus.install",
      "putty.install",
      "winscp.install",
      "postman",
      "vcredist140", # dependency for wireshark
      "wireshark",
      "jre8"
    )
  }
  "nomis-data-hub-development" = @{
    "DnsSuffixSearchList" = @(
      "nomis-data-hub.hmpps-development.modernisation-platform.internal",
      "azure.noms.root"
    )
  }
  "nomis-data-hub-test" = @{
    "DnsSuffixSearchList" = @(
      "nomis-data-hub.hmpps-test.modernisation-platform.internal",
      "azure.noms.root"
    )
  }
  "nomis-data-hub-preproduction" = @{
    "DnsSuffixSearchList" = @(
      "nomis-data-hub.hmpps-preproduction.modernisation-platform.internal",
      "azure.hmpp.root"
    )
  }
  "nomis-data-hub-production" = @{
     "DnsSuffixSearchList" = @(
       "nomis-data-hub.hmpps-production.modernisation-platform.internal",
       "azure.hmpp.root"
     )
  }
}

function Get-Config {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $EnvironmentNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "environment-name"}).Value

  if (-not $GlobalConfig.Contains($EnvironmentNameTag)) {
    Write-Error "Unexpected environment-name tag value $EnvironmentNameTag"
  }
  Return $GlobalConfig.all + $GlobalConfig[$EnvironmentNameTag]
}

function Add-Apps {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  foreach ($app in $Config.apps) {
    choco install $app -y
  }
}

function Add-SQLDeveloper {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  if (Test-Path "C:\Program Files\Oracle\sqldeveloper\sqldeveloper.exe") {
    Write-Output "SQL Developer already installed"
  } else {
    Write-Output "Add SQL Developer"
    Set-Location -Path ([System.IO.Path]::GetTempPath())
    Read-S3Object -BucketName $Config.SQLDeveloperS3Bucket -Key ($Config.SQLDeveloperS3Folder + "/sqldeveloper-22.2.1.234.1810-x64.zip") -File .\sqldeveloper-22.2.1.234.1810-x64.zip | Out-Null

    # Extract SQL Developer - there is no installer for this application
    Expand-Archive -Path .\sqldeveloper-22.2.1.234.1810-x64.zip -DestinationPath "C:\Program Files\Oracle" -Force | Out-Null

    # Create a desktop shortcut
    Write-Output " - Creating StartMenu Link"
    $Shortcut = New-Object -ComObject WScript.Shell
    $SourcePath = Join-Path -Path ([environment]::GetFolderPath("CommonStartMenu")) -ChildPath "\\SQL Developer.lnk"
    $ShortcutLink = $Shortcut.CreateShortcut($SourcePath)
    $ShortcutLink.TargetPath = "C:\Program Files\Oracle\sqldeveloper\sqldeveloper.exe"
    $ShortcutLink.Save() | Out-Null
  }
}

function Add-DnsSuffixSearchList {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  Write-Output "Setting DNS SuffixSearchList"
  $Config.DnsSuffixSearchList
  Set-DnsClientGlobalSetting -SuffixSearchList $Config.DnsSuffixSearchList | Out-Null
}

function Remove-StartMenuShutdownOption {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  Write-Output "Remove StartMenu Shutdown Option"
  $RegistryStartMenuPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\"
  if (Test-Path -Path $RegistryStartMenuPath) {
    Write-Output "Hiding Restart and Shutdown from Start Menu"
    Set-ItemProperty -Path "$($RegistryStartMenuPath)HideRestart" -Name "value" -Value 1
    Set-ItemProperty -Path "$($RegistryStartMenuPath)HideShutDown" -Name "value" -Value 1
  }
}

Set-TimeZone "GMT Standard Time"
Set-WinSystemLocale "en-GB"

$ScriptDir = Get-Location
$Config = Get-Config
Add-Apps $Config
Add-SQLDeveloper $Config
Add-DnsSuffixSearchList $Config
Remove-StartMenuShutdownOption $Config
Set-Location $ScriptDir
. ../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1
