# Join Domain
. ../ModPlatformAD/Join-ModPlatformAD.ps1

# Install RD Licensing component and activate
$ErrorActionPreference = "Stop"
Install-WindowsFeature AD-Domain-Services –IncludeAllSubFeature -IncludeManagementTools
