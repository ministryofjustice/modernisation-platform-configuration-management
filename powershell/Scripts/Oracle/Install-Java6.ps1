<#
.SYNOPSIS
    Install Java6

.EXAMPLE
    Install-Java6.ps1
#>

$JavaS3Bucket      = "mod-platform-image-artefact-bucket20230203091453221500000001"
$JavaS3Folder      = "hmpps/nomis/jumpserver-software"
$JavaInstallBinary = "jre-6u33-windows-i586.exe"
$JavaInstallLog    = "jre-6u33-windows-i586.log"
$JavaInstallDir    = "C:\Program Files (x86)\Java\jre6"

if (Test-Path $JavaInstallDir) {
  Write-Output "JRE already installed in $JavaInstallDir"
} else {
  $TempPath = [System.IO.Path]::GetTempPath()
  Write-Output "Installing JRE in $JavaInstallDir"
  Set-Location -Path $TempPath
  Write-Output " - Downloding installer from S3 bucket $JavaS3Bucket/$JavaS3Folder"
  Read-S3Object -BucketName $JavaS3Bucket -Key "$JavaS3Folder/$JavaInstallBinary" -File ".\$JavaInstallBinary" | Out-Null
  Write-Output " - Writing installer logs to $JavaInstallLog in $TempPath"
  Start-Process -Wait -Verbose -FilePath ".\$JavaInstallBinary" -ArgumentList "/s", "/L .\$JavaInstallLog"
}
