<#
.SYNOPSIS
    Download BIP Windows Installer components

.EXAMPLE
    Get-WindowsBIPSoftware.ps1
#>

$S3Bucket = "mod-platform-image-artefact-bucket20230203091453221500000001"
$S3Folder = "hmpps/mis"
$Files    = "DS4303P_4-80007397.EXE", "IPS4304P_900-70002778.EXE"
$SoftwareFolderPath = "D:\Software"

if (Test-Path $SoftwareFolderPath) {
    Write-Output "Software folder already exists: $SoftwareFolderPath"
} else {
    Write-Output "Creating software folder: $SoftwareFolderPath"
    New-Item -Type Directory -Path $SoftwareFolderPath -Force | Out-Null
}

foreach ($File in $Files) {
    $InstallerPath = Join-Path -Path $SoftwareFolderPath -ChildPath $File
    if (Test-Path $InstallerPath) {
        Write-Output "$File already downloaded"
    } else {
        Write-Output "Downloading $File"
        # Download the file from S3
        Read-S3Object -BucketName $S3Bucket -Key "$S3Folder/$File" -File "$InstallerPath" | Out-Null
    }
}
