$ErrorActionPreference = "Stop"

. ../ModPlatformAD/Join-ModPlatformAD.ps1

if ($LASTEXITCODE -ne 0) {
   Exit $LASTEXITCODE
}

$DomainNameNetbios = $ADConfig.DomainNameNetbios

$CAP = @{
  "Name" = "default"
  "AuthMethod" = 1
  "Status" = 1
  "IdleTimeout" = 120
  "SessionTimeout" = 480
  "SessionTimeoutAction" = 0
  "UserGroups" = "Domain Users@${DomainNameNetbios}"
}
$RAP = @{
  "Name" = "default"
  "ComputerGroupType" = 2
  "UserGroups" = "Domain Users@${DomainNameNetbios}"
}

Import-Module ModPlatformRemoteDesktop -Force
 
Add-ModPlatformRDGateway
Set-ModPlatformRDGatewayCAP @CAP
Set-ModPlatformRDGatewayRAP @RAP
