<#
.SYNOPSIS
    Install SQL Developer

.EXAMPLE
    Install-SQLDeveloper.ps1
#>

$SQLDeveloperS3Bucket = "mod-platform-image-artefact-bucket20230203091453221500000001"
$SQLDeveloperS3Folder = "hmpps/sqldeveloper"
$SQLDeveloperZip      = "sqldeveloper-22.2.1.234.1810-x64.zip"

if (Test-Path "C:\Program Files\Oracle\sqldeveloper\sqldeveloper.exe") {
  Write-Output "SQL Developer already installed"
} else {
  Write-Output "Installing SQL Developer"
  Set-Location -Path ([System.IO.Path]::GetTempPath())
  Read-S3Object -BucketName $SQLDeveloperS3Bucket -Key "$SQLDeveloperS3Folder/$SQLDeveloperZip" -File ".\$SQLDeveloperZip" | Out-Null

  # Extract SQL Developer - there is no installer for this application
  Expand-Archive -Path ".\$SQLDeveloperZip" -DestinationPath "C:\Program Files\Oracle" -Force | Out-Null

  # Create a desktop shortcut
  Write-Output "Creating SQL Developer CommonStartMenu Link"
  $Shortcut = New-Object -ComObject WScript.Shell
  $SourcePath = Join-Path -Path ([environment]::GetFolderPath("CommonStartMenu")) -ChildPath "\\SQL Developer.lnk"
  $ShortcutLink = $Shortcut.CreateShortcut($SourcePath)
  $ShortcutLink.TargetPath = "C:\Program Files\Oracle\sqldeveloper\sqldeveloper.exe"
  $ShortcutLink.Save() | Out-Null
}
