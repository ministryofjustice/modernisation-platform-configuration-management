<#
.SYNOPSIS
    Install Java Deployment Configuration

.DESCRIPTION
    Add HMPPS certificates, deployment configuration and deployment rule set.
    See dso-certificates repo for DeploymentRuleSet and trusted.certs

.EXAMPLE
    Install-JavaDeployment.ps1
#>

$JavaDeploymentFolder = "C:\Windows\Sun\Java\Deployment"
$JavaS3Bucket         = "mod-platform-image-artefact-bucket20230203091453221500000001"
$JavaS3Folder         = "hmpps/nomis/jumpserver-software"

Write-Output "Copying java deployment config to $JavaDeploymentFolder"
New-Item -Path $JavaDeploymentFolder -ItemType Directory -Force | Out-Null
if ($WhatIfPreference) {
  Write-Output "What-If: Read-S3Object -BucketName $JavaS3Bucket -Key $JavaS3Folder/deployment.config -File $JavaDeploymentFolder\deployment.config"
} else {
  Read-S3Object -BucketName $JavaS3Bucket -Key "$JavaS3Folder/deployment.config" -File "$JavaDeploymentFolder\deployment.config" | Out-Null
  Read-S3Object -BucketName $JavaS3Bucket -Key "$JavaS3Folder/deployment.properties" -File "$JavaDeploymentFolder\deployment.properties" | Out-Null
  Read-S3Object -BucketName $JavaS3Bucket -Key "$JavaS3Folder/trusted.certs" -File "$JavaDeploymentFolder\trusted.certs" | Out-Null
  Read-S3Object -BucketName $JavaS3Bucket -Key "$JavaS3Folder/DeploymentRuleSet.jar" -File "$JavaDeploymentFolder\DeploymentRuleSet.jar" | Out-Null
}
