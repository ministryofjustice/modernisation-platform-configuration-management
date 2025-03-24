$ErrorActionPreference = "Stop"

. ../ModPlatformAD/Join-ModPlatformAD.ps1
if ($LASTEXITCODE -ne 0) {
   Exit $LASTEXITCODE
}

. ../ModPlatformAD/Install-ADRemoteTools.ps1
if ($LASTEXITCODE -ne 0) {
   Exit $LASTEXITCODE
}

. ../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1
if ($LASTEXITCODE -ne 0) {
   Exit $LASTEXITCODE
}
