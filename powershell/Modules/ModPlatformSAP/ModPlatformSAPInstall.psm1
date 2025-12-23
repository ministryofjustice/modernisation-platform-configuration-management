function Get-SAPInstaller {
  param (
    [Parameter(Mandatory)][hashtable]$PackagesConfig
  )

  $Key  = ($PackagesConfig.PackagesPrefix) + '/' + $PackagesConfig.PackagesFile
  $File = Join-Path $PackagesConfig.WorkingDirectory -ChildPath $PackagesConfig.PackagesFile

  if (-not (Test-Path -PathType container $PackagesConfig.WorkingDirectory)) {
    Write-Output ("Creating " + $PackagesConfig.WorkingDirectory)
    New-Item -ItemType Directory -Path $PackagesConfig.WorkingDirectory | Out-Null
  }

  if (Test-Path $File) {
    Write-Debug ($PackagesConfig.PackagesFile + ": Already downloaded")
  } else {
    Write-Output ("Downloading " + $PackagesConfig.PackagesFile + " from " + $PackagesConfig.PackagesS3BucketName + '/' + $Key)
    Read-S3Object -BucketName $PackagesConfig.PackagesS3BucketName -Key $Key -File $File | Out-Null
  }
}

function Extract-SAPInstaller {
  param (
    [Parameter(Mandatory)][hashtable]$PackagesConfig
  )

  $File = Join-Path $PackagesConfig.WorkingDirectory -ChildPath $PackagesConfig.PackagesFile

  if (-not (Test-Path $File)) { 
    Write-Error "Install file not found: $File"    
  }
  $ExtractDir = (Get-Item $File).Basename

  if (-not (Test-Path -PathType container $ExtractDir)) {
    Write-Output ("Creating " + $ExtractDir)
    New-Item -ItemType Directory -Path $ExtractDir | Out-Null
  }

  if ($File -match '\.ZIP$') {
    Write-Output 'Extracting ZIP archive'
    Expand-Archive $File -Destination $ExtractDir
  } else {
    if (Get-Command unrar -ErrorAction SilentlyContinue) {
      Write-Output 'Extracting EXE archive'
      unrar x -r -f -y "$File" "$ExtractDir"
    } else {
      Write-Error 'Cannot extract EXE archive as unrar not found'
    }
  }
}

function Copy-TemplateFile {
  param (
    [Parameter(Mandatory)][string]$InTemplatePath,
    [Parameter(Mandatory)][string]$OutTemplatePath,
    [Parameter(Mandatory)][hashtable]$Config,
    [Parameter(Mandatory)][hashtable]$Secrets
  )

  $TemplateContent = Get-Content $InTemplatePath -Raw
  foreach ($Var in $Config.GetEnumerator()) {
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

Export-ModuleMember -Function Get-SAPInstaller
Export-ModuleMember -Function Extract-SAPInstaller
Export-ModuleMember -Function Copy-TemplateFile
