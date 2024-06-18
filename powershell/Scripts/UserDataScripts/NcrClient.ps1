$GlobalConfig = @{
    "all" = @{
         "WindowsClientS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
         "WindowsClientS3Folder" = "hmpps/ncr-packages"
         "WindowsClientS3File" = "WINDOWS.X64_193000_client.zip" # Oracle 19c client SW, install 1st
         "IPSS3File" = "IPS.ZIP" # IPS SW, install 2nd
         "DataServicesS3File" = "DATASERVICES.ZIP" # BODS SW, install 3rd
    }
    "nomis-combined-reporting-development" = @{
        "NcrShortcuts" = @{
        }
    }
    "nomis-combined-reporting-test"  = @{
        "NcrShortcuts" = @{
        }
    }
    "nomis-combined-reporting-preproduction" = @{
        "NcrShortcuts" = @{
        }
    }
    "nomis-combined-reporting-production" = @{
        "NcrShortcuts" = @{
        }
    }   
 }
$WorkingDirectory = "C:\Temp"
New-Item -ItemType Directory -Path $WorkingDirectory -Force
  
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
 
 # TODO: need to install these as well, just getting the files for now
 function Get-Software {
    [CmdletBinding()]
    param (
      [hashtable]$Config
    )
    Set-Location -Path $WorkingDirectory
    # Read-S3Object -BucketName $Config.WindowsClientS3Bucket -Key ($Config.WindowsClientS3Folder + "/" + $Config.WindowsClientS3File) -File (".\" + $Config.WindowsClientS3File) -Verbose | Out-Null
    Read-S3Object -BucketName $Config.WindowsClientS3Bucket -Key ($Config.WindowsClientS3Folder + "/" + $Config.IPSS3File) -File (".\" + $Config.IPSS3File) -Verbose | Out-Null
    Read-S3Object -BucketName $Config.WindowsClientS3Bucket -Key ($Config.WindowsClientS3Folder + "/" + $Config.DataServicesS3File) -File (".\" + $Config.DataServicesS3File) -Verbose | Out-Null
 }

 function Add-WindowsClient {
   [CmdletBinding()]
   param (
     [hashtable]$Config
   )
 
   $ErrorActionPreference = "Stop"
   # TODO the following may need a better path to test for installation
   # the current path may be good enough though,
   # as it's what's provided in the response file for installation
   if (Test-Path "C:\Program Files (x86)\Business Objects\") {
     Write-Output "Windows Client already installed"
   } else {
     Write-Output "Add Windows Client"
     Set-Location -Path $WorkingDirectory
     Read-S3Object -BucketName $Config.WindowsClientS3Bucket -Key ($Config.WindowsClientS3Folder + "/" + $Config.WindowsClientS3File) -File (".\" + $Config.WindowsClientS3File) -Verbose | Out-Null
 

     # FIXME: Expand-Archive path is too long for Windows, use C:\Windows\Temp possible? or just C:\Temp even
     # Extract Client Installer - there is no installer for this application
     # Expand-Archive -Path (".\" + $Config.WindowsClientS3File) -DestinationPath  ($WorkingDirectory + "\Client") -Force | Out-Null

     # Install Windows Client
    #  Start-Process -FilePath ($WorkingDirectory + "\Client\setup.exe") -ArgumentList "-r", "C:\Users\Administrator\AppData\Local\Temp\modernisation-platform-configuration-management\powershell\Configs\OnrClientResponse.ini" -Wait -NoNewWindow
     
     # TODO: change the shortcut path and remove reference to BOE
     # Create a desktop shortcut for Client Tools
    # $WScriptShell = New-Object -ComObject WScript.Shell
    # $targetPath = [System.IO.Path]::Combine([environment]::GetFolderPath("CommonStartMenu"), "Programs\BusinessObjects XI 3.1\BusinessObjects Enterprise Client Tools")
    # $shortcutPath = [System.IO.Path]::Combine([environment]::GetFolderPath("CommonDesktopDirectory"), "BOE Client Tools.lnk")
    # $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
    # $shortcut.TargetPath = $targetPath
    # $shortcut.Save() | Out-Null
    # Write-Output "Shortcut created at $shortcutPath"

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
  Get-ChildItem "${SourcePath}/*Ncr*" | ForEach-Object { Join-Path -Path $SourcePath -ChildPath $_.Name | Remove-Item }

  foreach ($Shortcut in $Config.NcrShortcuts.GetEnumerator()) {
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
  
 $ErrorActionPreference = "Stop"
 $Config = Get-Config
 Add-WindowsClient $Config
 Get-Software $Config
 # Add-Shortcuts $Config
 
 # clean up temporary working directory
 Remove-Item -Path $WorkingDirectory -Recurse -Force
