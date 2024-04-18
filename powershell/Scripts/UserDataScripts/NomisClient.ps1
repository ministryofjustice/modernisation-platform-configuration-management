$GlobalConfig = @{
  "all" = @{
    "JavaS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
    "JavaS3Folder" = "hmpps/nomis/jumpserver-software"
    "SQLDeveloperS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
    "SQLDeveloperS3Folder" = "hmpps/sqldeveloper"
    "CompatibilitySiteListPath" = "C:\\CompatibilitySiteList.xml"
  }
  "development" = @{
     "DnsSuffixSearchList" = @(
       "nomis.hmpps-test.modernisation-platform.internal",
       "azure.noms.root"
     )
  }
  "test" = @{
     "DnsSuffixSearchList" = @(
       "nomis.hmpps-test.modernisation-platform.internal",
       "azure.noms.root"
     )
    "IECompatibilityModeSiteList" = @(
      "t1-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t1-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t1-cn.hmpp-azdt.justice.gov.uk:7777/forms/frmservlet?config=tag",
      "t1-cn.hmpp-azdt.justice.gov.uk/forms/frmservlet?config=tag",
      "c-t1.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t2-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t2-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t2-cn.hmpp-azdt.justice.gov.uk/forms/frmservlet?config=tag",
      "c-t2.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t3-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t3-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t3-cn.hmpp-azdt.justice.gov.uk/forms/frmservlet?config=tag",
      "t3-cn-ha.hmpp-azdt.justice.gov.uk/forms/frmservlet?config=tag",
      "c-t3.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    )
    "IETrustedDomains" = @(
      "*.nomis.hmpps-test.modernisation-platform.justice.gov.uk",
      "*.nomis.service.justice.gov.uk",
      "*.hmpp-azdt.justice.gov.uk"
    )
    "StartMenuUrls" = @{
      "T1 NOMIS" = "https://c-t1.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "T2 NOMIS" = "https://c-t2.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "T3 NOMIS" = "https://c-t3.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    }
  }
  "preproduction" = @{
     "DnsSuffixSearchList" = @(
       "nomis.hmpps-preproduction.modernisation-platform.internal",
       "azure.hmpp.root"
     )
  }
  "production" = @{
     "DnsSuffixSearchList" = @(
       "nomis.hmpps-production.modernisation-platform.internal",
       "azure.hmpp.root"
     )
  }
}

function Get-Config {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $EnvironmentNameTag = ($Tags.Tags | Where-Object  {$_.Key -eq "environment-name"}).Value  
 
  Return $GlobalConfig.all + $GlobalConfig[$EnvironmentNameTag]
}

function Add-Java6 {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  # Download Java exe from S3 Bucket
  $ErrorActionPreference = "Stop"
  $TempPath = [System.IO.Path]::GetTempPath()
  Set-Location -Path $TempPath
  Write-Output "Downloding JRE installer"
  Read-S3Object -BucketName $Config.JavaS3Bucket -Key ($Config.JavaS3Folder + "/jre-6u33-windows-i586.exe") -File ".\jre-6u33-windows-i586.exe"
  
  # Install Java
  Write-Output "Installing JRE, jre-install.log file in $TempPath"
  Start-Process -Wait -Verbose -FilePath .\jre-6u33-windows-i586.exe -ArgumentList "/s", "/L .\jre-install.log"

  # Set JAVA_HOME environment variable
  [System.Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files (x86)\Java\jre6", [System.EnvironmentVariableTarget]::Machine)

  # Add Java to PATH environment variable
  [System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";%JAVA_HOME%\bin", [System.EnvironmentVariableTarget]::Machine)
}

function Add-JavaDeployment {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  # Copy deployment config files
  $ErrorActionPreference = "Stop"
  $DeploymentFolder = "C:\Windows\Sun\Java\Deployment"
  Write-Output "Downloading Java deployment config to $DeploymentFolder"
  New-Item -Path $DeploymentFolder -ItemType Directory -Force
  Read-S3Object -BucketName $Config.JavaS3Bucket -Key ($Config.JavaS3Folder + "/deployment.config") -File "$DeploymentFolder\deployment.config"
  Read-S3Object -BucketName $Config.JavaS3Bucket -Key ($Config.JavaS3Folder + "/deployment.properties") -File "$DeploymentFolder\deployment.properties"
  Read-S3Object -BucketName $Config.JavaS3Bucket -Key ($Config.JavaS3Folder + "/trusted.certs") -File "$DeploymentFolder\trusted.certs"
}

function Remove-JavaUpdateCheck {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  # Prevent Java update check
  $ErrorActionPreference = "Stop"
  $JavaPath = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"
  $ValueName = "SunJavaUpdateSched"
  $Properties = Get-ItemProperty -Path $JavaPath
  if ($Properties.PSObject.Properties.Name -contains $ValueName) {
    Write-Output "Removing $JavaPath $ValueName"
    Remove-ItemProperty -Path $JavaPath -Name $ValueName -Force
  }
}

function Add-EdgeConfig {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  $ErrorActionPreference = "Stop"
  $RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

  # Turn off Edge first run experience
  Write-Output "Updating Edge Config $RegPath"
  New-Item -Path $RegPath -Force
  New-ItemProperty -Path $RegPath -Name HideFirstRunExperience -Value 1 -PropertyType DWORD -Force

  # Turn on Edge IE Mode using RegPath from previous step
  New-ItemProperty -Path $RegPath -Name InternetExplorerIntegrationLevel -Value 1 -PropertyType DWORD -Force

  # Allow popups for .justice.gov.uk urls
  $RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\PopupsAllowedForUrls"
  New-Item -Path $RegPath -Force
  New-ItemProperty -Path $RegPath -Name 1 -Value "[*.]justice.gov.uk" -PropertyType String -Force
}

function Add-EdgeIECompatibility {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  $ErrorActionPreference = "Stop"

  Write-Output "Adding Edge IE Compatibility Mode"

  $XmlDoc = New-Object System.Xml.XmlDocument
  $Root = $XmlDoc.CreateElement("site-list")
  $Root.SetAttribute('version', 1)
  $XmlDoc.AppendChild($Root)
  $CreatedByElement = $XmlDoc.CreateElement("created-by")
  $ToolElement = $XmlDoc.CreateElement("tool")
  $VersionElement = $XmlDoc.CreateElement("version")
  $DateCreatedElement = $XmlDoc.CreateElement("date_created")
  $ToolElement.InnerText = "EMIESiteListManager"
  $VersionElement.InnerText = "10.0.0.0"
  $DateCreatedElement.InnerText = $(Get-Date -Format "MM/dd/yyyy hh:mm:ss")
  $CreatedByElement.AppendChild($ToolElement)
  $CreatedByElement.AppendChild($VersionElement)
  $CreatedByElement.AppendChild($DateCreatedElement)
  $Root.AppendChild($CreatedByElement)

  foreach ($site in $Config.IECompatibilityModeSiteList) {
    $SiteElement = $XmlDoc.CreateElement("site")
    $SiteElement.SetAttribute('url', $site)
    $CompatModeElement = $XmlDoc.CreateElement("compat-mode")
    $OpenInElement = $XmlDoc.CreateElement("open-in")
    $OpenInElement.SetAttribute('allow-redirect', 'true')
    $CompatModeElement.InnerText = "Default"
    $OpenInElement.InnerText = "IE11"
    $SiteElement.AppendChild($CompatModeElement)
    $SiteElement.AppendChild($OpenInElement)
    $Root.AppendChild($SiteElement)
  }

  $XmlDoc.Save($Config.CompatibilitySiteListPath)

  # Add compatibility list to registry
  New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name InternetExplorerIntegrationSiteList -Value $Config.CompatibilitySiteListPath -PropertyType String -Force
}

function Add-EdgeTrustedSites {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  $ErrorActionPreference = "Stop"
  Write-Output "Add Edge Trusted Sites"
  $Domains = $Config.IETrustedDomains

  # The jumpserver is using IE Enhanced Security so each domain needs to be explicitly added to the following
  # - Registry to allow certain domains to Bypass Enhanced Security (see below)
  # - Trusted Sites - HKCU, HKLM does not apply since the machine is not on the domain
  # NOTE: https:// traffic ONLY is allowed, these settings are external to this environment and are not managed by this script

  $RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\EnhanceSecurityModeBypassListDomains"

  # Ensure the registry path exists
  if (!(Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force
  }

  # Add each domain to the exclusion list for IE Enhanced Security
  # NOTE: subdomains are automatically included
  for ($i = 0; $i -lt $Domains.Length; $i++) {
    $Index = $i + 1
    $Value = $Domains[$i] -replace '^\*\.', ''

    New-Item -Path "$RegistryPath\$Index" -Force
    New-ItemProperty -Path "$RegistryPath\$Index" -Name "(Default)" -Value $Value -PropertyType String -Force
  }

  # Add each domain to the trusted sites list
  $Paths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains"
  )

  foreach ($Path in $Paths){
    $Domains | ForEach-Object {
      New-Item -Path $Path\$_ -Force
      New-ItemProperty -Path $Path\$_ -Name https -Value 2 -PropertyType DWORD -Force
    }
  }

  # Use Local Machine settings for Internet Security Settings
  $RegPath = "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"

  if (!(Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force
  }

  New-ItemProperty -Path $RegPath -Name Security_HKLM_only -Value 1 -PropertyType DWORD -Force
}

function Add-SQLDeveloper {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  $ErrorActionPreference = "Stop"
  Write-Output "Add SQL Developer"
  Set-Location -Path ([System.IO.Path]::GetTempPath())
  Read-S3Object -BucketName $Config.SQLDeveloperS3Bucket -Key ($Config.SQLDeveloperS3Folder + "/sqldeveloper-22.2.1.234.1810-x64.zip") -File .\sqldeveloper-22.2.1.234.1810-x64.zip

  # Extract SQL Developer - there is no installer for this application
  Expand-Archive -Path .\sqldeveloper-22.2.1.234.1810-x64.zip -DestinationPath "C:\Program Files\Oracle" -Force

  # Create a desktop shortcut
  $Shortcut = New-Object -ComObject WScript.Shell
  $SourcePath = Join-Path -Path ([environment]::GetFolderPath("CommonStartMenu")) -ChildPath "\\SQL Developer.lnk"
  $ShortcutLink = $Shortcut.CreateShortcut($SourcePath)
  $ShortcutLink.TargetPath = "C:\Program Files\Oracle\sqldeveloper\sqldeveloper.exe"
  $ShortcutLink.Save()
}

function Add-DnsSuffixSearchList {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  Set-DnsClientGlobalSetting -SuffixSearchList $Config.DnsSuffixSearchList
}

function Add-NomisShortcuts {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  $ErrorActionPreference = "Stop"
  Write-Output "Add Nomis Shortcuts"

  for ($Shortcut in $Config.StartMenuUrls.GetEnumerator())
    $Name = $Shortcut.Name
    $Url = $Shortcut.Value
    $Shortcut = New-Object -ComObject WScript.Shell
    $SourcePath = Join-Path -Path ([environment]::GetFolderPath("CommonStartMenu")) -ChildPath "\\$Name.url"
    $SourceShortcut = $Shortcut.CreateShortcut($SourcePath)
    $SourceShortcut.TargetPath = $Url

    $SourceShortcut.Save()
  }
}

function Remove-StartMenuShutdownOption {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  $ErrorActionPreference = "Stop"
  Write-Output "Remove StartMenu Shutdown Option"
  $RegistryStartMenuPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\"
  if (Test-Path -Path $RegistryStartMenuPath) {
    Write-Output "Hiding Restart and Shutdown from Start Menu"
    Set-ItemProperty -Path "$($RegistryStartMenuPath)HideRestart" -Name "value" -Value 1
    Set-ItemProperty -Path "$($RegistryStartMenuPath)HideShutDown" -Name "value" -Value 1
  }
}

$Config = Get-Config
Add-Java6 $Config
Add-JavaDeployment $Config
Remove-JavaUpdateCheck $Config
Add-EdgeConfig $Config
Add-EdgeIECompatibility $Config
Add-EdgeTrustedSites $Config
Add-SQLDeveloper $Config
Add-DnsSuffixSearchList $Config
Add-NomisShortcuts $Config
Remove-StartMenuShutdownOption $Config
