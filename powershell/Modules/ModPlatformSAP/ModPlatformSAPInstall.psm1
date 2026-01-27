function Get-SAPInstaller {
  param (
    [Parameter(Mandatory)][hashtable]$InstallPackage
  )

  $Key  = ($InstallPackage.S3Path) + '/' + $InstallPackage.S3File
  $File = Join-Path $InstallPackage.WorkingDir -ChildPath $InstallPackage.S3File

  if (-not (Test-Path -PathType container $InstallPackage.WorkingDir)) {
    Write-Output ("Creating " + $InstallPackage.WorkingDir)
    New-Item -ItemType Directory -Path $InstallPackage.WorkingDir | Out-Null
  }

  if (Test-Path $File) {
    Write-Debug ($InstallPackage.S3File + ": Already downloaded")
  } else {
    Write-Output ("Downloading " + $InstallPackage.S3BucketName + '/' + $Key + " to " + $File)
    Read-S3Object -BucketName $InstallPackage.S3BucketName -Key $Key -File $File | Out-Null
  }

  if ($InstallPackage.ContainsKey('S3Files')) {
    $S3Files = $InstallPackage.S3Files
    foreach ($S3File in $S3Files) {
      $Key  = ($InstallPackage.S3Path) + '/' + $S3File
      $File = Join-Path $InstallPackage.WorkingDir -ChildPath $S3File

      if (Test-Path $File) {
        Write-Debug ($S3File + ": Already downloaded")
      } else {
        Write-Output ("Downloading " + $InstallPackage.S3BucketName + '/' + $Key + " to " + $File)
        Read-S3Object -BucketName $InstallPackage.S3BucketName -Key $Key -File $File | Out-Null
      }
    }
  }
}

function Open-SAPInstaller {
  param (
    [Parameter(Mandatory)][hashtable]$InstallPackage
  )

  $File = Join-Path $InstallPackage.WorkingDir -ChildPath $InstallPackage.S3File

  if (-not (Test-Path $File)) {
    Write-Error "Install file not found: $File"
  }
  $ExtractPath = Join-Path $InstallPackage.WorkingDir -ChildPath $InstallPackage.ExtractDir

  if (-not (Test-Path -PathType container $ExtractPath)) {
    Write-Output ("Creating " + $ExtractPath)
    New-Item -ItemType Directory -Path $ExtractPath | Out-Null
  }

  $SetupExe = Join-Path $ExtractPath -ChildPath "setup.exe"
  if (Test-Path $SetupExe) {
    Write-Output "Skipping extract as $SetupExe already present"
    return
  }

  if ($File -match '\.ZIP$') {
    if ($InstallPackage.ContainsKey('S3Files')) {
      $AllFiles = @()
      $AllFiles += $File
      foreach ($S3File in $S3Files) {
        $AllFiles += (Join-Path $InstallPackage.WorkingDir -ChildPath $S3File)
      }
      Write-Output ("copy /b " + $AllFiles + " $File.joined")
      cmd.exe /c copy /b @AllFiles "$File.joined"
      Write-Output "Extracting multi-part ZIP archive to $ExtractPath"
      Expand-Archive "$File.joined" -DestinationPath $ExtractPath
    } else {
      Write-Output "Extracting ZIP archive to $ExtractPath"
      Expand-Archive $File -DestinationPath $ExtractPath
    }
  } else {
    if (Get-Command unrar -ErrorAction SilentlyContinue) {
      Write-Output "Extracting EXE archive to $ExtractPath"
      unrar x -r -y -idq "$File" "$ExtractPath"
    } else {
      Write-Error 'Cannot extract EXE archive as unrar not found'
    }
  }
}

function Copy-TemplateFile {
  param (
    [Parameter(Mandatory)][string]$InTemplatePath,
    [Parameter(Mandatory)][string]$OutTemplatePath,
    [Parameter(Mandatory)][hashtable]$Variables,
    [Parameter(Mandatory)][hashtable]$Secrets
  )

  $TemplateContent = Get-Content $InTemplatePath -Raw
  foreach ($Var in $Variables.GetEnumerator()) {
    $Key   = $Var.Name
    $Value = $Var.Value
    $TemplateContent = $TemplateContent -replace "\{$Key\}", $Value
  }
  foreach ($Var in $Secrets.GetEnumerator()) {
    $Key   = $Var.Name
    $Value = $Var.Value
    $TemplateContent = $TemplateContent -replace "\{$Key\}", $Value
  }
  $TemplateContent | Out-File -FilePath $OutTemplatePath -Force -Encoding ascii
}

function Copy-SAPResponseFile {
  param (
    [Parameter(Mandatory)][string]$TopLevelRepoPath,
    [Parameter(Mandatory)][string]$ResponseFilename,
    [Parameter(Mandatory)][hashtable]$InstallPackage,
    [Parameter(Mandatory)][hashtable]$Variables,
    [Parameter(Mandatory)][hashtable]$Secrets
  )

  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $NameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "Name"}).Value
  $EnvironmentNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "environment-name"}).Value
  if (-not $NameTag) {
    Write-Error "Missing Name tag"
  }
  if (-not $EnvironmentNameTag) {
    Write-Error "Missing environment-name tag"
  }
  $NameTagIndex = $NameTag.split("-")[-1]

  $SourceBasePath = Join-Path $TopLevelRepoPath -ChildPath "Configs"
  $SourceBasePath = Join-Path $SourceBasePath -ChildPath "SAP"
  $SourceBasePath = Join-Path $SourceBasePath -ChildPath "ResponseFiles"
  $SourceEnvPath  = Join-Path $SourceBasePath -ChildPath $EnvironmentNameTag

  $SourceFiles = @(
    (Join-Path $SourceEnvPath -ChildPath ($ResponseFilename + "." + "$NameTag")),
    (Join-Path $SourceEnvPath -ChildPath ($ResponseFilename + "." + "$NameTagIndex")),
    (Join-Path $SourceEnvPath -ChildPath $ResponseFilename),
    (Join-Path $SourceBasePath -ChildPath ($ResponseFilename + "." + "$NameTag")),
    (Join-Path $SourceBasePath -ChildPath ($ResponseFilename + "." + "$NameTagIndex")),
    (Join-Path $SourceBasePath -ChildPath $ResponseFilename)
  )
  $SourceFile = $null
  foreach ($SourceFileIter in $SourceFiles) {
    if (Test-Path $SourceFileIter) {
      $SourceFile = $SourceFileIter
      break
    }
  }
  if (-not $SourceFile) {
    Write-Error "Cannot find response file in repo $ResponseFilename $EnvironmentNameTag $NameTag"
  }
  $DestinationPath = Join-Path $InstallPackage.WorkingDir -ChildPath $InstallPackage.ExtractDir
  $DestinationFile = Join-Path $DestinationPath -ChildPath $ResponseFilename

  Write-Output "Copying response file $SourceFile $DestinationFile"
  Copy-TemplateFile $SourceFile $DestinationFile $Variables $Secrets
}

function Add-SAPDirectories {
  param (
    [Parameter(Mandatory)][hashtable]$Variables
  )

  $DirEnvVars = @{
    'DS_COMMON_DIR' = $Variables.DSCommonDir
  }

  foreach ($DirEnv in $DirEnvVars.GetEnumerator()) {
    if (-not (Test-Path $DirEnv.Value)) {
      Write-Output ("Creating Directory " + $DirEnv.Value)
      New-Item -ItemType Directory -Path $DirEnv.Value -Force | Out-Null
    }
  }
}

function Set-SAPEnvironmentVars {
  param (
    [Parameter(Mandatory)][hashtable]$Variables
  )

  $DirEnvVars = @{
    'DS_COMMON_DIR' = $Variables.DSCommonDir
    'LINK_DIR'      = $Variables.LinkDir
  }

  foreach ($DirEnv in $DirEnvVars.GetEnumerator()) {
    if ([Environment]::GetEnvironmentVariable($DirEnv.Name, [System.EnvironmentVariableTarget]::Machine) -ne $DirEnv.Value) {
      Write-Output ("Setting Machine Env Variable " + $DirEnv.Name + "=" + $DirEnv.Value)
      [Environment]::SetEnvironmentVariable($DirEnv.Name, $DirEnv.Value, [System.EnvironmentVariableTarget]::Machine)
    }
  }
}

function Install-SAPIPS {
  param (
    [Parameter(Mandatory)][string]$ResponseFilename,
    [Parameter(Mandatory)][hashtable]$InstallPackage,
    [Parameter(Mandatory)][hashtable]$Secrets
  )

  $File = Join-Path $InstallPackage.WorkingDir -ChildPath $InstallPackage.InstallPackagesFile
  if (-not (Test-Path $File)) {
    Write-Error "Install file not found: $File"
  }

  $ExtractPath  = Join-Path $InstallPackage.WorkingDir -ChildPath $InstallPackage.ExtractDir
  $ResponsePath = Join-Path $ExtractPath -ChildPath $ResponseFilename
  $SetupExe     = Join-Path $ExtractPath -ChildPath "setup.exe"
  $LogFile      = Join-Path $ExtractPath -ChildPath "install.log"
  $LogErrFile   = Join-Path $ExtractPath -ChildPath "install-error.log"

  if (-not (Test-Path $ResponsePath)) {
    Write-Error "Response file not found: $ResponsePath"
  }

  if (-not (Test-Path $SetupExe)) {
    Write-Error "Setup.exe not found: $SetupExe"
  }

  if (Test-Path $LogFile) {
    Write-Output "Remove $LogFile to force re-install"
    return
  }

  $CMSPassword   = $Secrets.CmsAdminPassword
  $AuditPassword = $Secrets.AudDbPassword
  $SysPassword   = $Secrets.SysDbPassword

  if (-not $CMSPassword -or -not $AuditPassword -or -not $SysPassword) {
    Write-Error "Missing one or more secrets for cmspassword, existingauditingdbpassword, existingcmsdbpassword command line args"
  }

  $InstallArgs = @(
    "/wait",
    "-r $ResponsePath",
    "cmspassword=$CMSPassword",
    "existingauditingdbpassword=$AuditPassword",
    "existingcmsdbpassword=$SysPassword"
  )
  $InstallArgsDebug = @(
    "/wait",
    "-r $ResponsePath",
    "cmspassword=***",
    "existingauditingdbpassword=***",
    "existingcmsdbpassword=***"
  )

  Write-Output "Launching at $(Get-Date): $SetupExe $InstallArgsDebug"
  "Launching at $(Get-Date): $SetupExe $InstallArgsDebug" | Out-File -FilePath $LogFile -Append
  $Process = Start-Process -FilePath $SetupExe -ArgumentList $InstallArgs -Wait -NoNewWindow -Verbose -PassThru -RedirectStandardError $LogErrFile
  $InstallProcessId = $Process.Id
  $ExitCode = $Process.ExitCode

  "Process ID: $InstallProcessId" | Out-File -FilePath $LogFile -Append
  "Exit Code: $ExitCode" | Out-File -FilePath $LogFile -Append
  "Completed at: $(Get-Date)" | Out-File -FilePath $LogFile -Append

  Write-Output "Process ID: $InstallProcessId"
  Write-Output "Exit Code: $ExitCode"
  Write-Output "Completed at: $(Get-Date)"
}

function Set-SAPIPSServiceControl {
  param (
    [Parameter(Mandatory)][hashtable]$Variables,
    [Parameter(Mandatory)][hashtable]$Secrets
  )

  $ServiceNames = @(
    "Server Intelligence Agent*",
    "Apache Tomcat*"
  )

  $ServiceUser         = $Variables.ServiceUser
  $ServiceUserPassword = $Secrets.ServiceUserPassword

  foreach ($Service in $ServiceNames) {
    $ServiceName = (Get-Service | Where-Object { $_.DisplayName -like $Service }).Name

    if ($ServiceName) {
      Write-Output "Setting $ServiceName to Automatic (Delayed Start)"
      sc.exe config $ServiceName start=delayed-auto

      Write-Output "Setting $ServiceName to RunAs $ServiceUser"
      sc.exe config $ServiceName obj=$ServiceUser password=$ServiceUserPassword
    } else {
      Write-Error "Could not find service matching $Service"
    }
  }
}

function Install-SAPDataServices {
  param (
    [Parameter(Mandatory)][string]$ResponseFilename,
    [Parameter(Mandatory)][hashtable]$InstallPackage,
    [Parameter(Mandatory)][hashtable]$Secrets
  )

  $ExistingDataServices = Get-Package | Where-Object { $_.Name -like 'SAP Data Services*' }
  if ($ExistingDataServices) {
    Write-Output "Data Services is already installed: $($ExistingDataServices.Name) v$($ExistingDataServices.Version)"
    return
  }

  $File = Join-Path $InstallPackage.WorkingDir -ChildPath $InstallPackage.InstallPackagesFile
  if (-not (Test-Path $File)) {
    Write-Error "Install file not found: $File"
  }

  $ExtractPath  = Join-Path $InstallPackage.WorkingDir -ChildPath $InstallPackage.ExtractDir
  $ResponsePath = Join-Path $ExtractPath -ChildPath $ResponseFilename
  $SetupExe     = Join-Path $ExtractPath -ChildPath "setup.exe"
  $LogFile      = Join-Path $ExtractPath -ChildPath "install.log"
  $LogErrFile   = Join-Path $ExtractPath -ChildPath "install-error.log"

  if (-not (Test-Path $ResponsePath)) {
    Write-Error "Response file not found: $ResponsePath"
  }

  if (-not (Test-Path $SetupExe)) {
    Write-Error "Setup.exe not found: $SetupExe"
  }

  if (Test-Path $LogFile) {
    Write-Output "Remove $LogFile to force re-install"
    return
  }

  $CMSPassword         = $Secrets.CmsAdminPassword
  $ServiceUserPassword = $Secrets.ServiceUserPassword

  if (-not $CMSPassword -or -not $ServiceUserPassword) {
    Write-Error "Missing one or more secrets for cmspassword, dslogininfothispassword command line args"
  }

  $InstallArgs = @(
    "-q",
    "-r $ResponsePath",
    "cmspassword=$CMSPassword",
    "dscmspassword=$CMSPassword",
    "dslogininfothispassword=$ServiceUserPassword"
  )
  $InstallArgsDebug = @(
    "-q",
    "-r $ResponsePath",
    "cmspassword=***",
    "dscmspassword=***",
    "dslogininfothispassword=***"
  )

  Write-Output "Launching at $(Get-Date): $SetupExe $InstallArgsDebug"
  "Launching at $(Get-Date): $SetupExe $InstallArgsDebug" | Out-File -FilePath $LogFile -Append
  $Process = Start-Process -FilePath $SetupExe -ArgumentList $InstallArgs -Wait -NoNewWindow -Verbose -PassThru -RedirectStandardError $LogErrFile
  $InstallProcessId = $Process.Id
  $ExitCode = $Process.ExitCode

  "Process ID: $InstallProcessId" | Out-File -FilePath $LogFile -Append
  "Exit Code: $ExitCode" | Out-File -FilePath $LogFile -Append
  "Completed at: $(Get-Date)" | Out-File -FilePath $LogFile -Append

  Write-Output "Process ID: $InstallProcessId"
  Write-Output "Exit Code: $ExitCode"
  Write-Output "Completed at: $(Get-Date)"
}

function Set-SAPDataServicesServiceControl {
  $ServiceNames = @(
    "SAP Data Services*"
  )

  foreach ($Service in $ServiceNames) {
    $ServiceName = (Get-Service | Where-Object { $_.DisplayName -like $Service }).Name

    if ($ServiceName) {
      Write-Output "Setting $ServiceName to Automatic (Delayed Start)"
      sc.exe config $ServiceName start=delayed-auto
    } else {
      Write-Error "Could not find service matching $Service"
    }
  }
}

function Install-SAPClient {
  param (
    [Parameter(Mandatory)][string]$ResponseFilename,
    [Parameter(Mandatory)][hashtable]$InstallPackage
  )

  $ExistingClient = Get-Package | Where-Object { $_.Name -like 'SAP BusinessObjects*Client*' }
  if ($ExistingClient) {
    Write-Output "Client is already installed: $($ExistingClient.Name) v$($ExistingClient.Version)"
    return
  }

  $File = Join-Path $InstallPackage.WorkingDir -ChildPath $InstallPackage.InstallPackagesFile
  if (-not (Test-Path $File)) {
    Write-Error "Install file not found: $File"
  }

  $ExtractPath  = Join-Path $InstallPackage.WorkingDir -ChildPath $InstallPackage.ExtractDir
  $ResponsePath = Join-Path $ExtractPath -ChildPath $ResponseFilename
  $SetupExe     = Join-Path $ExtractPath -ChildPath "setup.exe"
  $LogFile      = Join-Path $ExtractPath -ChildPath "install.log"
  $LogErrFile   = Join-Path $ExtractPath -ChildPath "install-error.log"

  if (-not (Test-Path $ResponsePath)) {
    Write-Error "Response file not found: $ResponsePath"
  }

  if (-not (Test-Path $SetupExe)) {
    Write-Error "Setup.exe not found: $SetupExe"
  }

  if (Test-Path $LogFile) {
    Write-Output "Remove $LogFile to force re-install"
    return
  }

  $InstallArgs = @(
    "/wait",
    "-q",
    "-r $ResponsePath"
  )
  $InstallArgsDebug = @(
    "/wait",
    "-q",
    "-r $ResponsePath"
  )

  Write-Output "Launching at $(Get-Date): $SetupExe $InstallArgsDebug"
  "Launching at $(Get-Date): $SetupExe $InstallArgsDebug" | Out-File -FilePath $LogFile -Append
  $Process = Start-Process -FilePath $SetupExe -ArgumentList $InstallArgs -Wait -NoNewWindow -Verbose -PassThru -RedirectStandardError $LogErrFile
  $InstallProcessId = $Process.Id
  $ExitCode = $Process.ExitCode

  "Process ID: $InstallProcessId" | Out-File -FilePath $LogFile -Append
  "Exit Code: $ExitCode" | Out-File -FilePath $LogFile -Append
  "Completed at: $(Get-Date)" | Out-File -FilePath $LogFile -Append

  Write-Output "Process ID: $InstallProcessId"
  Write-Output "Exit Code: $ExitCode"
  Write-Output "Completed at: $(Get-Date)"
}

Export-ModuleMember -Function Get-SAPInstaller
Export-ModuleMember -Function Open-SAPInstaller
Export-ModuleMember -Function Copy-SAPResponseFile
Export-ModuleMember -Function Add-SAPDirectories
Export-ModuleMember -Function Set-SAPEnvironmentVars
Export-ModuleMember -Function Install-SAPIPS
Export-ModuleMember -Function Set-SAPIPSServiceControl
Export-ModuleMember -Function Install-SAPDataServices
Export-ModuleMember -Function Set-SAPDataServicesServiceControl
Export-ModuleMember -Function Install-SAPClient
