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

.PARAMETER GitBranch
    Git branch to checkout, e.g. main

.PARAMETER GitCloneDir
    Optionally specify location to clone repo, otherwise temp dir is used

.EXAMPLE
    Run-GitScript.ps1 -Script "ModPlatformAD/Join-ModPlatformAD" -ScriptArgs @{"DomainNameFQDN" = "azure.noms.root"}
#>

param (
  [string]$Script,
  [hashtable]$ScriptArgs,
  [string]$GitBranch = "main",
  [string]$GitCloneDir
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
  $RelativeScriptDir = Split-Path -Parent $Script
  $ScriptFilename = Split-Path -Leaf $Script
  Set-Location -Path (Join-Path (Join-Path "powershell" "Scripts") $RelativeScriptDir)
  . ./$ScriptFilename @ScriptArgs
  $ScriptExitCode = $LASTEXITCODE
  Write-Output "Script $ScriptFilename completed with ExitCode $ScriptExitCode"
  Exit $ScriptExitCode
} else {
  Set-Location -Path (Join-Path "powershell" "Scripts")
}
