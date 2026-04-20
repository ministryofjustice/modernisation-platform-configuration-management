$S3BucketName = 'mod-platform-image-artefact-bucket20230203091453221500000001'
$S3File       = 'peopleware-client-11828.msi'
$S3Path       = 'hmpps/csr'
$LogFile      = 'peopleware-client-11828.log'
$S3Key        = $S3Path + '/' + $S3File
$WorkingDir   = 'C:\Software'
$InstallPath  = 'C:\Program Files (x86)\InVision WFM\Client'

$MSIPath      = Join-Path $WorkingDir -ChildPath $S3File
$LogPath      = Join-Path $WorkingDir -ChildPath $LogFile

$ExistingClient = Get-Package | Where-Object { $_.Name -like 'Peopleware Client*' }
if ($ExistingClient) {
  Write-Output "Client is already installed: $($ExistingClient.Name) v$($ExistingClient.Version)"
} else {
  if (-not (Test-Path -PathType container $WorkingDir)) {
    Write-Output ("Creating " + $WorkingDir)
    New-Item -ItemType Directory -Path $WorkingDir | Out-Null
  }

  if (Test-Path $MSIPath) {
    Write-Debug ($S3File + ": Already downloaded")
  } else {
    Write-Output ("Downloading " + $S3BucketName + '/' + $S3Key + " to " + $MSIPath)
    Read-S3Object -BucketName $S3BucketName -Key $S3Key -File $MSIPath | Out-Null
  }

  $InstallerRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Installer"
  $DisableMSI = -1
  if (Test-Path $InstallerRegPath) {
    $DisableMSI = (Get-ItemProperty -Path $InstallerRegPath -Name DisableMSI -ErrorAction SilentlyContinue).DisableMSI
  } else {
    Write-Output "Creating $InstallerRegPath"
    New-Item -Path $InstallerRegPath -Force | Out-Null
  }
  if ($DisableMSI -ne 0) {
    Write-Output "Setting $InstallerRegPath DisableMSI=0"
    Set-ItemProperty -Path $InstallerRegPath -Name DisableMSI -Value 0 -Type DWord
  }

  if (-not (Test-Path -PathType container $InstallPath)) {
    Write-Output ("Creating " + $InstallPath)
    New-Item -ItemType Directory -Path $InstallPath | Out-Null
  }

  $MSIArgList = @(
    "/i", "`"$MSIPath`"",
    "INSTALLFOLDER=`"$InstallPath`"",
    "ALLUSERS=1",
    "/qn", "/norestart",
    "/L*V", "`"$LogPath`""
  )

  $process  = Start-Process "msiexec.exe" -ArgumentList $MSIArgList -Wait -PassThru
  $exitCode = $process.ExitCode

  if ($exitCode -eq 0) {
    Write-Output ($S3File + ": The installation completed successfully")
  } elseif ($exitCode -eq 3010) {
    Write-Output ($S3File + ": The installation completed, but a reboot is required")
    exit $exitCode
  } else {
    Write-Output ($S3File + ": ERROR: The installation failed with exit code $exitCode")
    exit $exitCode
  }
}

$renameFile = Join-Path $InstallPath "ShiftCenterApp.exe"

if (Test-Path $renameFile) {
  Write-Output "Renaming $renameFile"
  Rename-Item -Path $renameFile -NewName ShiftCenterApp.noexe -Force -ErrorAction SilentlyContinue
}

# Update Permissions
$UserGroup   = "Users"
$Rights      = "ReadAndExecute"
$Inheritance = [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit"
$Propagation = [System.Security.AccessControl.PropagationFlags]"None"
$Type        = [System.Security.AccessControl.AccessControlType]"Allow"
$AccessRule  = New-Object System.Security.AccessControl.FileSystemAccessRule($UserGroup, $Rights, $Inheritance, $Propagation, $Type)

Write-Output "Setting install folder permissions"
$ACL = Get-Acl $InstallPath
$ACL.SetAccessRule($AccessRule)
Set-Acl $InstallPath $ACL

# Re-Run RegDLL script with "Short Paths" as it doesn't work otherwise
& "C:\Program Files (x86)\InVision WFM\Client\regdll.bat" /s C:\PROGRA~2\INVISI~1\Client\
