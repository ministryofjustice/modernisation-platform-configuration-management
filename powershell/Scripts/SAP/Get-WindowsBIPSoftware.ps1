<#
.SYNOPSIS
    Download BIP Windows Installer components

.EXAMPLE
    Get-WindowsBIPSoftware.ps1
#>

$S3Bucket = "mod-platform-image-artefact-bucket20230203091453221500000001"
$S3Folder = "hmpps/bip-windows-installer"
$Files    = "BIPLATS4207P_600-80001043_P1.EXE", "BIPLATS4207P_600-80001043_P2.RAR"
$SoftwareFolderPath = "C:\Software\"

foreach ($File in $Files) {
    if (Test-Path $InstallerPath) {
        Write-Output "$File already downloaded"
    } else {
        Write-Output "Downloading $File"
        $InstallerPath = Join-Path -Path $SoftwareFolderPath -ChildPath $File
        # Ensure the path is created before downloading
        New-Item -Type Directory -Path $SoftwareFolderPath -Force | Out-Null
        # Download the file from S3
        Read-S3Object -BucketName $S3Bucket -Key "$S3Folder/$File" -File "$InstallerPath" | Out-Null
    }
}
