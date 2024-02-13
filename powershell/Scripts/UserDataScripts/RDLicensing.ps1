Import-Module ModPlatformRemoteDesktop -Force

# Join Domain
. ../ModPlatformAD/Join-ModPlatformAD.ps1

# Install RD Licensing component and activate
$ErrorActionPreference = "Stop"
Install-WindowsFeature RDS-Licensing -IncludeAllSubFeature -IncludeManagementTools
$CompanyInformation = Get-ModPlatformRDLicensingCompanyInformation
Add-ModPlatformRDLicensingActivation $CompanyInformation
