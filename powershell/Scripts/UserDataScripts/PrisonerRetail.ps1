$ErrorActionPreference = "Stop"

. ../ModPlatformAD/Join-ModPlatformAD.ps1 -NewHostname "keep-existing"

if ($LASTEXITCODE -ne 0) {
   Exit $LASTEXITCODE
}
