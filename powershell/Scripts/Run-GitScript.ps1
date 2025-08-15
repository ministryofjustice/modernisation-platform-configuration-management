<#
.SYNOPSIS
    Clone git repo and run powershell script

.DESCRIPTION
    Clone repo, configure modules and run given powershell script

.PARAMETER Script
    Optionally provide a script to run.
    Specify relative path of script from Modules/Scripts directory

.PARAMETER ScriptArgs
    Optionally provide arguments to the script in hashtable format

.PARAMETER ScriptArgsList
    Optionally provide arguments to the script in list format

.PARAMETER GitBranch
    Git branch to checkout, e.g. main

.PARAMETER GitCloneDir
    Optionally specify location to clone repo, otherwise temp dir is used

.PARAMETER Username
    Optionally specify a username to run the script under. Only parameters passed in via ScriptArgList will work.
    Use tag.username to extract the username from a tag of your choosing, e.g. username

.EXAMPLE
    Run-GitScript.ps1 -Script "ModPlatformAD/Join-ModPlatformAD" -ScriptArgs @{"DomainNameFQDN" = "azure.noms.root"}
#>

param (
  [string]$Script,
  [hashtable]$ScriptArgs,
  [string[]]$ScriptArgsList,
  [string]$GitBranch = "main",
  [string]$GitCloneDir,
  [string]$Username
)

$ErrorActionPreference = "Stop"
$GitOrg = "ministryofjustice"
$GitRepo = "modernisation-platform-configuration-management"

if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
  Write-Error "Please install git, e.g. choco install git.install -y"
  Exit 1
}

if (-not $GitCloneDir) {
  $GitCloneDir = [System.IO.Path]::GetTempPath()
}

$env:GIT_REDIRECT_STDERR="2>&1"
Set-Location -Path $GitCloneDir

if (Test-Path -Path $GitRepo) {
   Write-Output "Removing existing git clone directory"
   cmd /c "rd $GitRepo /s /q"
}

Write-Output "git config --global http.sslBackend openssl"
git config --global http.sslBackend "openssl" # without this, git clone intermittently fails

$attempts = 10
$attemptCount = 1
$downloaded = $false

while (-not $downloaded -and $attemptCount -le $attempts) {
  Write-Output "Attempt $attemptCount of $attempts : git clone https://github.com/${GitOrg}/${GitRepo}.git into $GitCloneDir"
  git -c core.longpaths=true clone --ipv4 --quiet "https://github.com/${GitOrg}/${GitRepo}.git"

  if ($LASTEXITCODE -eq 0) {
    Write-Output "Repository cloned successfully on attempt $attemptCount"
    $downloaded = $true
  }
  else {
    Write-Output "Failed to clone repository on attempt $attemptCount. Retrying..."
    if ($attemptCount -le $attempts) {
      Write-Output "Waiting 20 seconds before retrying..."
      Start-Sleep -Seconds 20
      $attemptCount++
    }
    else {
      Write-Error "Failed to clone repository after $attempts attempts"
      Exit 1
    }
  }
}
Set-Location -Path $GitRepo
if ($GitBranch -ne "main") {
  git checkout "${GitBranch}"
}
$ModulePath = Join-Path (Join-Path $GitCloneDir $GitRepo) (Join-Path "powershell" "Modules")
if (-not $env:PSModulePath.Split(";").Contains($ModulePath)) {
  $env:PSModulePath = "${env:PSModulePath};${ModulePath}"
}
if ($Script) {
  if ($Username) {
    if ($ScriptArgs) {
      Write-Error "Cannot run script under a username using the -ScriptArgs parameter, use -ScriptArgsList instead"
      Exit 1
    }
    if ($Username.StartsWith("tag.")) {
      $TagValue = $Username.Split(".")[-1]
      $ErrorActionPreference = "Stop"
      $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
      $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
      $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
      $Tags = "$TagsRaw" | ConvertFrom-Json
      $Username = ($Tags.Tags | Where-Object  {$_.Key -eq $TagValue}).Value
      if (-Not $Username) {
        Write-Error("Cannot extract username from tag $TagValue")
        Exit 1
      }
      Write-Output("Using username $Username from tag $TagValue")
    }

    Import-Module ModPlatformAD -Force
    $ADConfig = Get-ModPlatformADConfig
    $ADSecret = Get-ModPlatformADSecret $ADConfig
    if (-not (Get-Member -inputobject $ADSecret -name $Username -Membertype Properties)) {
      Write-Error ("Cannot find username '$Username' in secret " + $ModPlatformADConfig.SecretName)
      Exit 1
    }
    $SecurePassword = ConvertTo-SecureString $ADSecret.$Username -AsPlainText -Force
    $Credentials = New-Object System.Management.Automation.PSCredential(($Config.domain+"\"+$Username), $SecurePassword)
    $ArgumentList = @($Script,$ScriptArgs,$ScriptArgsList,$GitBranch)
    Write-Output "Invoke-Command -FilePath $PSCommandPath -ArgumentList $ArgumentList -Authentication Credssp -ComputerName $env:computername"
    $ScriptOutput = Invoke-Command -ComputerName $env:computername -FilePath $PSCommandPath -Authentication Credssp -Credential $Credentials -ArgumentList $ArgumentList
    $ScriptOutput
    if ($ScriptOutput.Split('\n')[-1] -match 'completed with ExitCode (\d+)') {
      $ScriptExitCode = $Matches[1]
    } else {
      Write-Error "Could not extract ExitCode from script output"
      $ScriptExitCode = 1
    }
    Write-Output "Script $PSCommandPath completed with ExitCode $ScriptExitCode as user $Username"
    Exit $ScriptExitCode
  } else {
    $RelativeScriptDir = Split-Path -Parent $Script
    $ScriptFilename = Split-Path -Leaf $Script
    Set-Location -Path (Join-Path (Join-Path "powershell" "Scripts") $RelativeScriptDir)
    if ($ScriptArgs) {
      if ($ScriptArgsList) {
        Write-Error "Both -ScriptArgs and -ScriptArgsList set, only use one of them"
        Exit 1
      }
      . ./$ScriptFilename @ScriptArgs
    } elseif ($ScriptArgsList) {
      . ./$ScriptFilename @ScriptArgsList
    } else {
      . ./$ScriptFilename
    }
    $ScriptExitCode = $LASTEXITCODE
    Write-Output "Script $ScriptFilename completed with ExitCode $ScriptExitCode"
    Exit $ScriptExitCode
  }
} else {
  Set-Location -Path (Join-Path "powershell" "Scripts")
}
