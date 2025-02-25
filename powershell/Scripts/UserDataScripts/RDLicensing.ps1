$ErrorActionPreference = "Stop"

. ../ModPlatformAD/Join-ModPlatformAD.ps1
if ($LASTEXITCODE -ne 0) {
   Exit $LASTEXITCODE
}

Install-WindowsFeature RDS-Licensing -IncludeAllSubFeature -IncludeManagementTools

Import-Module ModPlatformRemoteDesktop -Force
$CompanyInformation = Get-ModPlatformRDLicensingCompanyInformation
Add-ModPlatformRDLicensingActivation $CompanyInformation

# Get the InstanceId
$Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
$InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id

# Install the AWS VSS Components via SSM
$documentName = "AWS-ConfigureAWSPackage"
$parameters = @{
    "action" = "Install"
    "name" = "AwsVssComponents"
}
Send-SSMCommand -InstanceId $instanceId -DocumentName $documentName -Parameters $parameters

# Install the Cloudwatch Agent with out baseline config
. ../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1
