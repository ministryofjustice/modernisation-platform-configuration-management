<#
.SYNOPSIS
    Download Symantec PGP 10.3.2 installer

.EXAMPLE
    Get-PGPInstaller.ps1
#>

$S3Bucket = "mod-platform-image-artefact-bucket20230203091453221500000001"
$S3Folder = "hmpps/pgp"
$File      = "SymantecEncryptionDesktopWin64-10.3.2MP9.exe"
$SoftwareFolderPath = "C:\Software\PGPInstaller"
$InstallerPath = $SoftwareFolderPath + "\" + $File

if (Test-Path $InstallerPath) {
    Write-Output "Symantec PGP 10.3.2 already downloaded"
} else {
    New-Item -Type Directory -Path $SoftwareFolderPath -Force | Out-Null
    Write-Output "Downloading Symantec PGP 10.3.2"
    Read-S3Object -BucketName $S3Bucket -Key "$S3Folder/$File" -File "$InstallerPath" | Out-Null
}
