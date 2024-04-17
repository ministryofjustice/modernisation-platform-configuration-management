$JAVA_S3_BUCKET="mod-platform-image-artefact-bucket20230203091453221500000001"
$JAVA_S3_FOLDER="hmpps/nomis/jumpserver-software"
$SQLDEVELOPER_S3_BUCKET="mod-platform-image-artefact-bucket20230203091453221500000001"
$SQLDEVELOPER_S3_FOLDER="hmpps/sqldeveloper"
$SSM_PARAM_NAME = "/nomis-client/config"
$COMPATIBILITY_SITE_LIST_PATH = "C:\\compatibility_site_list.xml"

function Add-Java6 {
  # Download Java exe from S3 Bucket
  $ErrorActionPreference = "Stop"
  $TempPath = [System.IO.Path]::GetTempPath()
  Set-Location -Path $TempPath
  Write-Output "Downloding JRE installer"
  Read-S3Object -BucketName $JAVA_S3_BUCKET -Key "$JAVA_S3_FOLDER/jre-6u33-windows-i586.exe" -File ".\jre-6u33-windows-i586.exe"
  
  # Install Java
  Write-Output "Installing JRE, jre-install.log file in $TempPath"
  Start-Process -Wait -Verbose -FilePath .\jre-6u33-windows-i586.exe -ArgumentList "/s", "/L .\jre-install.log"

  # Set JAVA_HOME environment variable
  [System.Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files (x86)\Java\jre6", [System.EnvironmentVariableTarget]::Machine)

  # Add Java to PATH environment variable
  [System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";%JAVA_HOME%\bin", [System.EnvironmentVariableTarget]::Machine)
}

function Add-JavaDeployment {
  # Copy deployment config files
  $ErrorActionPreference = "Stop"
  $DeploymentFolder = "C:\Windows\Sun\Java\Deployment"
  Write-Output "Downloading Java deployment config from $JAVA_S3_BUCKET to $DeploymentFolder"
  New-Item -Path $DeploymentFolder -ItemType Directory -Force
  Read-S3Object -BucketName $JAVA_S3_BUCKET -Key "$JAVA_S3_FOLDER/deployment.config" -File "$DeploymentFolder\deployment.config"
  Read-S3Object -BucketName $JAVA_S3_BUCKET -Key "$JAVA_S3_FOLDER/deployment.properties" -File "$DeploymentFolder\deployment.properties"
  Read-S3Object -BucketName $JAVA_S3_BUCKET -Key "$JAVA_S3_FOLDER/trusted.certs" -File "$DeploymentFolder\trusted.certs"
}

function Remove-JavaUpdateCheck {
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
  $ErrorActionPreference = "Stop"

  Write-Output "Add IE Compatibility: retriving config from SSM $SSM_PARAM_NAME"
  $SSMParamRaw = aws ssm get-parameter --name $SSM_PARAM_NAME --with-decryption --query Parameter.Value --output text
  $SSMParam = "$SSMParamRaw" | ConvertFrom-Json
  $IECompatSiteList = $SSMParam.ie_compatibility_mode_site_list

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

  foreach ($site in $IECompatSiteList) {
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

  $XmlDoc.Save($COMPATIBILITY_SITE_LIST_PATH)

  # Add compatibility list to registry
  New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name InternetExplorerIntegrationSiteList -Value $COMPATIBILITY_SITE_LIST_PATH -PropertyType String -Force
}

function Add-EdgeTrustedSites {
  $ErrorActionPreference = "Stop"
  Write-Output "Add Edge Trusted Sites: retriving config from SSM $SSM_PARAM_NAME"
  $SSMParamRaw = aws ssm get-parameter --name $SSM_PARAM_NAME --with-decryption --query Parameter.Value --output text
  $SSMParam = "$SSMParamRaw" | ConvertFrom-Json
  $Domains = $SSMParam.ie_trusted_domains

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
  $ErrorActionPreference = "Stop"
  Write-Output "Add SQL Developer"
  Set-Location -Path ([System.IO.Path]::GetTempPath())
  Read-S3Object -BucketName $SQLDEVELOPER_S3_BUCKET -Key "$SQLDEVELOPER_S3_FOLDER/sqldeveloper-22.2.1.234.1810-x64.zip" -File .\sqldeveloper-22.2.1.234.1810-x64.zip

  # Extract SQL Developer - there is no installer for this application
  Expand-Archive -Path .\sqldeveloper-22.2.1.234.1810-x64.zip -DestinationPath "C:\Program Files\Oracle" -Force

  # Create a desktop shortcut
  $Shortcut = New-Object -ComObject WScript.Shell
  $ShortcutLink = $Shortcut.CreateShortcut("C:\Users\Public\Desktop\SQL Developer.lnk")
  $ShortcutLink.TargetPath = "C:\Program Files\Oracle\sqldeveloper\sqldeveloper.exe"
  $ShortcutLink.Save()
}

function Add-NomisShortcuts {
  $ErrorActionPreference = "Stop"
  Write-Output "Add Nomis Shortcuts: retriving config from SSM $SSM_PARAM_NAME"
  $SSMParamRaw = aws ssm get-parameter --name $SSM_PARAM_NAME --with-decryption --query Parameter.Value --output text
  $SSMParam = "$SSMParamRaw" | ConvertFrom-Json
  $Shortcuts = $SSMParam.desktop_shortcuts

  for ($i = 0; $i -lt $Shortcuts.Length; $i++) {
    $Shortcut = $Shortcuts[$i].Split('|')
    $Name = $Shortcut[0]
    $Url = $Shortcut[1]
    $Shortcut = New-Object -ComObject WScript.Shell
    $Destination = $Shortcut.SpecialFolders.Item("AllUsersDesktop")
    $SourcePath = Join-Path -Path $Destination -ChildPath "\\$Name.url"
    $SourceShortcut = $Shortcut.CreateShortcut($SourcePath)
    $SourceShortcut.TargetPath = $Url

    $SourceShortcut.Save()
  }
}

function Remove-StartMenuShutdownOption {
  $ErrorActionPreference = "Stop"
  Write-Output "Remove StartMenu Shutdown Option"
  $RegistryStartMenuPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\"
  if (Test-Path -Path $RegistryStartMenuPath) {
    Write-Output "Hiding Restart and Shutdown from Start Menu"
    Set-ItemProperty -Path "$($RegistryStartMenuPath)HideRestart" -Name "value" -Value 1
    Set-ItemProperty -Path "$($RegistryStartMenuPath)HideShutDown" -Name "value" -Value 1
  }
}

Add-Java6
Add-JavaDeployment
Remove-JavaUpdateCheck
Add-EdgeConfig
Add-EdgeIECompatibility
Add-EdgeTrustedSites
Add-SQLDeveloper
Add-NomisShortcuts
Remove-StartMenuShutdownOption