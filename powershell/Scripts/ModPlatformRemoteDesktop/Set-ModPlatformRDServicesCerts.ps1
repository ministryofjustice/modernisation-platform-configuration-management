. ../ModPlatformRemoteDesktop/Import-ModPlatformRDCerts.ps1 -CertFilename "star-azure-hmpp-root.pfx"
. ../ModPlatformRemoteDesktop/Set-RDDeploymentCert.ps1 -CertName "*.azure.hmpp.root" -RDRole "RDPublishing"
. ../ModPlatformRemoteDesktop/Set-RDDeploymentCert.ps1 -CertName "*.azure.hmpp.root" -RDRole "RDRedirector"
. ../ModPlatformRemoteDesktop/Set-RDHostCert.ps1 -CertName "*.azure.hmpp.root"
