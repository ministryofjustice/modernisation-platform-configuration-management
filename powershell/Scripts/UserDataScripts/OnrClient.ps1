# $path = [Environment]::GetFolderPath("MyDocuments")
# "Hello World" | Out-File -FilePath "$path\file.txt"
$GlobalConfig = @{
    "all" = @{
         "BOEWindowsClientS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
         "BOEWindowsClientS3Folder" = "hmpps/onr"
    }
    "oasys-national-reporting-test"  = @{}   
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
     Read-S3Object -BucketName $Config.BOEWindowsClientS3Bucket -Key ($Config.BOEWindowsClientS3Folder + "/51048121.ZIP") -File .\51048121.ZIP -Verbose | Out-Null
 
     # Extract BOE Client Installer - there is no installer for this application
     Expand-Archive -Path .\51048121.ZIP -DestinationPath  (([System.IO.Path]::GetTempPath()) + "\BOE") -Force | Out-Null

     # Install BOE Windows Client
     Start-Process -FilePath (([System.IO.Path]::GetTempPath()) + "\BOE\setup.exe") -ArgumentList "-r", "C:\Users\Administrator\AppData\Local\Temp\modernisation-platform-configuration-management\powershell\Configs\OnrClientResponse.ini" -Wait -NoNewWindow
     
     # Create a desktop shortcut for SAP BO Universe Designer
     Write-Output " - Creating StartMenu Link"
     $Shortcut = New-Object -ComObject WScript.Shell
     $SourcePath = Join-Path -Path ([environment]::GetFolderPath("CommonStartMenu")) -ChildPath "\\SAP Universe Designer.lnk"
     $ShortcutLink = $Shortcut.CreateShortcut($SourcePath)
     $ShortcutLink.TargetPath = "C:\Program Files (x86)\Business Objects\BusinessObjects Enterprise 12.0\win32_x86\designer.exe"
     $ShortcutLink.Save() | Out-Null
   }
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
 Add-BOEWindowsClient $Config
