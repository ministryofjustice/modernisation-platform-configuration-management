$ErrorActionPreference = "Stop"

. ../ModPlatformAD/Join-ModPlatformAD.ps1
if ($LASTEXITCODE -ne 0) {
   Exit $LASTEXITCODE
}

Install-WindowsFeature RDS-Licensing -IncludeAllSubFeature -IncludeManagementTools

Import-Module ModPlatformRemoteDesktop -Force
$CompanyInformation = Get-ModPlatformRDLicensingCompanyInformation
Add-ModPlatformRDLicensingActivation $CompanyInformation
