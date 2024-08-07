$GlobalConfig = @{
    "all" = @{
         "BOEWindowsClientS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
         "BOEWindowsClientS3Folder" = "hmpps/onr"
         "BOEWindowsClientS3File" = "51048121.ZIP"
         "RegistryPath" = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon"
         "LegalNoticeCaption" = "IMPORTANT"
         "LegalNoticeText" = "This system is restricted to authorized users only. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information"
    }
    "oasys-national-reporting-test"  = @{
      "OnrShortcuts" = @{
        "Onr CmcApp" = "http://t2-onr-web-1-a.oasys-national-reporting.hmpps-test.modernisation-platform.service.justice.gov.uk:7777/CmcApp"

      }
    }
    "oasys-national-reporting-preproduction" = @{
      "OnrShortcuts" = @{

      }
    }
    "oasys-national-reporting-production" = @{
      "OnrShortcuts" = @{

      }
    }   
 }
  
 function Get-Config {
   $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
   $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
   $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
   $Tags = "$TagsRaw" | ConvertFrom-Json
   $EnvironmentNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "environment-name"}).Value
 
   if (-not $GlobalConfig.Contains($EnvironmentNameTag)) {
     Write-Error "Unexpected environment-name tag value $EnvironmentNameTag"
   }
   Return $GlobalConfig.all + $GlobalConfig[$EnvironmentNameTag]
 }
 
 function Add-BOEWindowsClient {
   [CmdletBinding()]
   param (
     [hashtable]$Config
   )
 
   $ErrorActionPreference = "Stop"
   if (Test-Path (([System.IO.Path]::GetTempPath()) + "\BOE\setup.exe")) {
     Write-Output "BOE Windows Client already installed"
   } else {
     Write-Output "Add BOE Windows Client"
     Set-Location -Path ([System.IO.Path]::GetTempPath())
     Read-S3Object -BucketName $Config.BOEWindowsClientS3Bucket -Key ($Config.BOEWindowsClientS3Folder + "/" + $Config.BOEWindowsClientS3File) -File (".\" + $Config.BOEWindowsClientS3File) -Verbose | Out-Null
 
     # Extract BOE Client Installer - there is no installer for this application
     Expand-Archive -Path (".\" + $Config.BOEWindowsClientS3File) -DestinationPath  (([System.IO.Path]::GetTempPath()) + "\BOE") -Force | Out-Null

     # Install BOE Windows Client
     Start-Process -FilePath (([System.IO.Path]::GetTempPath()) + "\BOE\setup.exe") -ArgumentList "-r", "C:\Users\Administrator\AppData\Local\Temp\modernisation-platform-configuration-management\powershell\Configs\OnrClientResponse.ini" -Wait -NoNewWindow
     
     # Create a desktop shortcut for BOE Client Tools
    $WScriptShell = New-Object -ComObject WScript.Shell
    $targetPath = [System.IO.Path]::Combine([environment]::GetFolderPath("CommonStartMenu"), "Programs\BusinessObjects XI 3.1\BusinessObjects Enterprise Client Tools")
    $shortcutPath = [System.IO.Path]::Combine([environment]::GetFolderPath("CommonDesktopDirectory"), "BOE Client Tools.lnk")
    $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $targetPath
    $shortcut.Save() | Out-Null
    Write-Output "Shortcut created at $shortcutPath"

   }
 }

 function Add-Shortcuts {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  $ErrorActionPreference = "Stop"
  Write-Output "Add Shortcuts"
  Write-Output " - Removing existing shortcuts"
  Get-ChildItem "${SourcePath}/*Onr*" | ForEach-Object { Join-Path -Path $SourcePath -ChildPath $_.Name | Remove-Item }

  foreach ($Shortcut in $Config.OnrShortcuts.GetEnumerator()) {
    $Name = $Shortcut.Name
    $Url = $Shortcut.Value
    Write-Output " - Add $Name $Url"
    $Shortcut = New-Object -ComObject WScript.Shell
    $SourcePath = Join-Path -Path ([environment]::GetFolderPath("CommonDesktopDirectory")) -ChildPath "\\$Name.url"
    $SourceShortcut = $Shortcut.CreateShortcut($SourcePath)
    $SourceShortcut.TargetPath = $Url
    $SourceShortcut.Save()
  }
}

# Apply to all environments that aren't on the domain
function Add-LoginText {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  $ErrorActionPreference = "Stop"
  Write-Output "Add Legal Notice"
  
  if (-NOT (Test-Path $Config.RegistryPath)) {
    Write-Output " - Registry path does not exist, creating"
    New-Item -Path $Config.RegistryPath -Force | Out-Null
  }

  $RegistryPath = $Config.RegistryPath
  $LegalNoticeCaption = $Config.LegalNoticeCaption
  $LegalNoticeText = $Config.LegalNoticeText

  Write-Output " - Set Legal Notice Caption"
  New-ItemProperty -Path $RegistryPath -Name LegalNoticeCaption -Value $LegalNoticeCaption -PropertyType String -Force

  Write-Output " - Set Legal Notice Text"
  New-ItemProperty -Path $RegistryPath -Name LegalNoticeText -Value $LegalNoticeText -PropertyType String -Force
}

 # Install PowerShell 5.1 if running on PowerShell 4 or below
 if ( $PSVersionTable.PSVersion.Major -le 4 ) {
    choco install powershell -y
    # reboot when run from ssm doc
    exit 3010
 }

 choco install winscp.install -y
  
 $ErrorActionPreference = "Stop"
 $Config = Get-Config
 Add-LoginText $Config
 Add-BOEWindowsClient $Config
 Add-Shortcuts $Config
