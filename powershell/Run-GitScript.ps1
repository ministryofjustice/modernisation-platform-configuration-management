param (
  #[Parameter(Mandatory=$true)][string]$Script,
  [string]$Script = "ModPlatformAD/Join-ModPlatformAD",
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

git config --system core.longpaths true

if (-Not $GitSourcePath) {
  $GitSourcePath = [System.IO.Path]::GetTempPath()
}

$env:GIT_REDIRECT_STDERR="2>&1"
Set-Location -Path $GitSourcePath
if (-not (Test-Path -Path $GitRepo)) {
  Write-Output "git clone https://github.com/${GitOrg}/${GitRepo}.git"
  git clone "https://github.com/${GitOrg}/${GitRepo}.git"
  Set-Location -Path $GitRepo
} else {
  Set-Location -Path $GitRepo
  git checkout main
  git pull
}
if ($GitBranch -ne "main") {
  git checkout "${GitBranch}"
}
$ModulePath = Join-Path (Join-Path $GitSourcePath $GitRepo) (Join-Path "powershell" "Modules")
$env:PSModulePath = "${env:PSModulePath};${ModulePath}"

. powershell/Scripts/$Script
