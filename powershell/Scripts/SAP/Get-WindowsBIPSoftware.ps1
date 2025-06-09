<#
.SYNOPSIS
    Download BIP Windows Installer components

.EXAMPLE
    Get-WindowsBIPSoftware.ps1
#>

$S3Bucket = "mod-platform-image-artefact-bucket20230203091453221500000001"
$S3Folder = "hmpps/bip-windows-installer"
$Files    = "BIPLATS4207P_600-80001043_P1.EXE", "BIPLATS4207P_600-80001043_P2.RAR"
$SoftwareFolderPath = "C:\Software"

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
