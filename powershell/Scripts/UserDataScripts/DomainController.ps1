$ErrorActionPreference = "Stop"

. ../ModPlatformAD/Join-ModPlatformAD.ps1
if ($LASTEXITCODE -ne 0) {
   Exit $LASTEXITCODE
}

Install-WindowsFeature AD-Domain-Services -IncludeAllSubFeature -IncludeManagementTools
