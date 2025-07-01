<#
.SYNOPSIS
    Install Cortex Windows Agent

.EXAMPLE
    Install-CortexAgent.ps1
#>

$CortexAgentS3Bucket = "mod-platform-image-artefact-bucket20230203091453221500000001"
$CortexAgentS3Folder = "hmpps/XSIAM/Agents/Windows"
$CortexAgentMsi      = "xsiam_LIVE_win_8_8_0_10622_x64.msi"

if (Test-Path "C:/Program Files/Palo Alto Networks/Traps") {
  Write-Output "Cortex Agent already installed"
} else {
  Set-Location -Path ([System.IO.Path]::GetTempPath())
  $LocalMsiPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath $CortexAgentMsi
  Write-Output "Downloading Cortex Agent"
  Read-S3Object -BucketName $CortexAgentS3Bucket -Key "$CortexAgentS3Folder/$CortexAgentMsi" -File ".\$CortexAgentMsi" | Out-Null
  Write-Output "Installing CortexAgent"
  Start-Process -FilePath "msiexec.exe" -ArgumentList "/i `"$LocalMsiPath`" /quiet /norestart" -Wait
}
