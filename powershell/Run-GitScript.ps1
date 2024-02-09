param (
  [Parameter(Mandatory=$true)][string]$Script,
  [string]$GitOrg = "ministryofjustice",
  [string]$GitRepo = "modernisation-platform-configuration-management",
  [string]$GitBranch = "hmpps/DSOS-2581/add-active-directory-scripts",
  [string]$GitSourcePath
)

$ErrorActionPreference = "Stop"

if (-not (Get-Command "git" -ErrorAction SilentlyContinue)) {
  Write-Error "Please install git, e.g. choco install git or brew install git"
  exit 1
}

$TempPath = $null
if (-Not $GitSourcePath) {
  $TempPath = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
  Write-Output "Creating temporary directory ${TempPath}"
  $TempPathItem = New-Item -ItemType Directory -Path $TempPath
  $GitSourcePath = $TempPath
}

if (-not (Test-Path -Path (Join-Path $GitSourcePath $GitRepo))) {
  Set-Location -Path $GitSourcePath
  Write-Output "git clone https://github.com/${GitOrg}/${GitRepo}.git"
  $env:GIT_REDIRECT_STDERR="2>&1"
  git clone "https://github.com/${GitOrg}/${GitRepo}.git"
}
Set-Location -Path (Join-Path $GitSourcePath $GitRepo)
git checkout $GitBranch
$ModulePath = Join-Path $GitSourcePath $GitRepo "powershell/Modules"
$env:PSModulePath = "${env:PSModulePath}:${ModulePath}"

. powershell/Scripts/$Script
