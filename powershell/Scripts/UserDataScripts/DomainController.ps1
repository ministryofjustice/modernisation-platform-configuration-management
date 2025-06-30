# Install the Cloudwatch Agent with out baseline config
. ../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1

. ../Common/Set-TimezoneGMT.ps1
. ../Microsoft/Remove-EdgeFirstRunExperience.ps1
. ../Microsoft/Add-DnsSuffixSearchList.ps1 -ConfigName core-shared-services-production-hmpp

. ../ModPlatformAD/Install-ModPlatformADDomainController.ps1
if ($LASTEXITCODE -ne 0) {
   Exit $LASTEXITCODE
}

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
