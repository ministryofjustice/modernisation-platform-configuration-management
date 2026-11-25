$GlobalConfig = @{
  "test-rds-1-a" = @{
    "CertSelfSigned" = $true
    "CertName"       = "test-rds-1-a.azure.noms.root"
    "CertFilename"   = "test-rds-1-a-azure-noms-root.pfx" # Update filename to force new cert to be generated
    "S3CertDir"      = "s3://s3-bucket20230824125932809600000001/self-signed-certs/pfx/"
  }
  "pp-rds-1-a"   = @{
    "CertSelfSigned" = $false
    "CertName"       = "*.azure.hmpp.root"
    "CertFilename"   = "star-azure-hmpp-root.pfx"
    "S3CertDir"      = "s3://mod-platform-image-artefact-bucket20230203091453221500000001/hmpps/dso-certificates/ca-signed/pfx/"
  }
  "pd-rds-1-a"   = @{
    "CertSelfSigned" = $false
    "CertName"       = "*.azure.hmpp.root"
    "CertFilename"   = "star-azure-hmpp-root.pfx"
    "S3CertDir"      = "s3://mod-platform-image-artefact-bucket20230203091453221500000001/hmpps/dso-certificates/ca-signed/pfx/"
  }
}

function Get-Config {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = 3600 } -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token } -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $NameTag = ($Tags.Tags | Where-Object { $_.Key -eq "Name" }).Value

  if (-not $GlobalConfig.Contains($NameTag)) {
    Write-Error "Unexpected Name tag value $NameTag"
  }
  Return $GlobalConfig[$NameTag]
}

$Config = Get-Config

if ($Config.CertSelfSigned) {
  . ../ModPlatformRemoteDesktop/New-ModPlatformRDCerts.ps1 -CertName $Config.CertName  -CertFilename $Config.CertFilename -S3CertDir $Config.S3CertDir
}
. ../ModPlatformRemoteDesktop/Import-ModPlatformRDCerts.ps1 -CertFilename $Config.CertFilename -S3CertDir $Config.S3CertDir
. ../ModPlatformRemoteDesktop/Set-RDDeploymentCert.ps1 -CertName $Config.CertName -RDRole "RDPublishing"
. ../ModPlatformRemoteDesktop/Set-RDDeploymentCert.ps1 -CertName $Config.CertName -RDRole "RDRedirector"
. ../ModPlatformRemoteDesktop/Set-RDHostCert.ps1 -CertName $Config.CertName
