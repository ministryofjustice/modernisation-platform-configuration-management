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

  if ($File -match '\.ZIP$') {
    Write-Output "Extracting ZIP archive to $ExtractPath"
    Expand-Archive $File -DestinationPath $ExtractPath
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
    [Parameter(Mandatory)][string]$InstallPackage,
    [Parameter(Mandatory)][string]$Variables,
    [Parameter(Mandatory)][string]$Secrets
  )

  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $NameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "Name"}).Value
  $EnvironmentNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "environment-name"}).Value

  $SourcePath = Join-Path $TopLevelRepoPath -ChildPath "Configs"
  $SourcePath = Join-Path $SourcePath -ChildPath "SAP"
  $SourcePath = Join-Path $SourcePath -ChildPath "ResponseFiles"
  $SourcePath = Join-Path $SourcePath -ChildPath $EnvironmentNameTag
  $SourceFile = Join-Path $SourcePath -ChildPath ($ResponseFilename + "." + "$NameTag")

  if (-not (Test-Path $SourceFile)) {
    $SourceFile = Join-Path $SourcePath -ChildPath $ResponseFilename
  }
  if (-not (Test-Path $SourceFile)) {
    Write-Error "Cannot find $SourceFile"
  }
  $DestinationPath = Join-Path $InstallPackage.WorkingDir -ChildPath $InstallPackage.ExtractDir
  $DestinationFile = Join-Path $DestinationPath -ChildPath $ResponseFilename

  Copy-TemplateFile $SourceFile $DestinationFile $Variables $Secrets
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
    if (-not (Test-Path $DirEnv.Value)) {
      Write-Output ("Creating Directory " + $DirEnv.Value)
      New-Item -ItemType Directory -Path $DirEnv.Value -Force | Out-Null
    }
    if ([Environment]::GetEnvironmentVariable($DirEnv.Name, [System.EnvironmentVariableTarget]::Machine) -ne $DirEnv.Value) {
      Write-Output ("Setting Machine Env Variable " + $DirEnv.Name + "=" + $DirEnv.Value)
      [Environment]::SetEnvironmentVariable($DirEnv.Name, $DirEnv.Value, [System.EnvironmentVariableTarget]::Machine)
    }
  }
}

#function Install-IPS {
#  param (
#    [Parameter(Mandatory)][hashtable]$InstallPackage
#  )
#
#  $File = Join-Path $InstallPackage.WorkingDir -ChildPath $InstallPackage.InstallPackagesFile
#  if (-not (Test-Path $File)) {
#    Write-Error "Install file not found: $File"
#  }
#  $ExtractPath = Join-Path $InstallPackage.WorkingDirectory -ChildPath (Get-Item $File).Basename
#
#  $SetupExe = Join-Path $ExtractPath -ChildPath "setup.exe"
#  if (-not (Test-Path $SetupExe)) {
#    Write-Error "Setup.exe not found: $SetupExe"
#  }
#
#  $InstallArgs = @(
#    '/wait',
#    '-r .\IPS\ips_install.ini',
#    "cmspassword=$bods_cluster_key",
#    "existingauditingdbpassword=$bods_ips_audit_owner",
#    "existingcmsdbpassword=$bods_ips_system_owner"
#  )
#  + $responseFileResult.CommandLineArgs
#}

Export-ModuleMember -Function Get-SAPInstaller
Export-ModuleMember -Function Open-SAPInstaller
Export-ModuleMember -Function Copy-SAPResponseFile
Export-ModuleMember -Function Set-SAPEnvironmentVars
