$GlobalConfig = @{
  "all" = @{
    "JavaS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
    "JavaS3Folder" = "hmpps/nomis/jumpserver-software"
    "JavaNomisWebUtilsS3Object" = "JavaNomisWebUtils-20170718.zip"
    "SQLDeveloperS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
    "SQLDeveloperS3Folder" = "hmpps/sqldeveloper"
    "CompatibilitySiteListPath" = "C:\\CompatibilitySiteList.xml"
  }
  "nomis-development" = @{
    "DnsSuffixSearchList" = @(
      "us-east-1.ec2-utilities.amazonaws.com",
      "eu-west-2.compute.internal",
      "eu-west-2.ec2-utilities.amazonaws.com",
      "nomis.hmpps-development.modernisation-platform.internal",
      "azure.noms.root"
    )
    "IECompatibilityModeSiteList" = @(
      "c-dev.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c-qa11g.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c-qa11r.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    )
    "IETrustedDomains" = @(
      "*.nomis.service.justice.gov.uk"
    )
    "NomisShortcuts" = @{
      "Prison-Nomis DEV" = "https://c-dev.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "Prison-Nomis QA11G" = "https://c-qa11g.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "Prison-Nomis QA11R" = "https://c-qa11r.development.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    }
  }
  "nomis-test" = @{
    "DnsSuffixSearchList" = @(
      "us-east-1.ec2-utilities.amazonaws.com",
      "eu-west-2.compute.internal",
      "eu-west-2.ec2-utilities.amazonaws.com",
      "nomis.hmpps-test.modernisation-platform.internal",
      "azure.noms.root"
    )
    "IECompatibilityModeSiteList" = @(
      "c-t1.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c-t2.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c-t3.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t1-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t1-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t2-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t2-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t3-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "t3-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    )
    "IETrustedDomains" = @(
      "*.nomis.service.justice.gov.uk"
    )
    "NomisShortcuts" = @{
      "Prison-Nomis T1" = "https://c-t1.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "Prison-Nomis T2" = "https://c-t2.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "Prison-Nomis T3" = "https://c-t3.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "LB t1-nomis-web-a Nomis" = "https://t1-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "LB t1-nomis-web-b Nomis" = "https://t1-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "LB t2-nomis-web-a Nomis" = "https://t2-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "LB t2-nomis-web-b Nomis" = "https://t2-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "LB t3-nomis-web-a Nomis" = "https://t3-nomis-web-a.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "LB t3-nomis-web-b Nomis" = "https://t3-nomis-web-b.test.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    }
  }
  "nomis-preproduction" = @{
    "DnsSuffixSearchList" = @(
      "us-east-1.ec2-utilities.amazonaws.com",
      "eu-west-2.compute.internal",
      "eu-west-2.ec2-utilities.amazonaws.com",
      "nomis.hmpps-preproduction.modernisation-platform.internal",
      "azure.hmpp.root"
    )
    "IECompatibilityModeSiteList" = @(
      "c-lsast.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "lsast-nomis-web-a.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "lsast-nomis-web-b.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "preprod-nomis-web-a.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "preprod-nomis-web-b.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    )
    "IETrustedDomains" = @(
      "*.nomis.service.justice.gov.uk"
    )
    "NomisShortcuts" = @{
      "Prison-Nomis Lsast"           = "https://c-lsast.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "Prison-Nomis Preproduction"   = "https://c.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "LB lsast-nomis-web-a Nomis"   = "https://lsast-nomis-web-a.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "LB lsast-nomis-web-b Nomis"   = "https://lsast-nomis-web-b.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "LB preprod-nomis-web-a Nomis" = "https://preprod-nomis-web-a.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "LB preprod-nomis-web-b Nomis" = "https://preprod-nomis-web-b.preproduction.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    }
  }
  "nomis-production" = @{
    "DnsSuffixSearchList" = @(
      "us-east-1.ec2-utilities.amazonaws.com",
      "eu-west-2.compute.internal",
      "eu-west-2.ec2-utilities.amazonaws.com",
      "nomis.hmpps-production.modernisation-platform.internal",
      "azure.hmpp.root"
    )
    "IECompatibilityModeSiteList" = @(
      "c.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "c.nomis.az.justice.gov.uk/forms/frmservlet?config=tag",
      "c.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "prod-nomis-web-a.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag",
      "prod-nomis-web-b.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
    )
    "IETrustedDomains" = @(
      "*.nomis.service.justice.gov.uk"
    )
    "NomisShortcuts" = @{
      "Prison-Nomis" = "https://c.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "LB prod-nomis-web-a Nomis" = "https://prod-nomis-web-a.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
      "LB prod-nomis-web-b Nomis" = "https://prod-nomis-web-b.production.nomis.service.justice.gov.uk/forms/frmservlet?config=tag"
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

function Add-EC2InstanceToConfig {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  Write-Output "Retrieving EC2 instances to add to config"
  $Ec2Raw = aws ec2 describe-instances --no-cli-pager --filters 'Name=instance-state-name,Values=running'
  $Ec2Json = $Ec2Raw | ConvertFrom-Json

  for ($i = 0; $i -lt $Ec2Json.Reservations.Length; $i++) {
    for ($j = 0; $j -lt $Ec2Json.Reservations[$i].Instances.Length; $j++) {
      $Instance = $Ec2Json.Reservations[$i].Instances[$j]
      if ($Instance.Tags | Where-Object {$_.Key -eq "server-type"} | Where-Object {$_.Value -eq "nomis-web"}) {
        $Name = ($Instance.Tags | Where-Object {$_.Key -eq "Name"})[0].Value
        $IP = $Instance.PrivateIpAddress
        $ID = $Instance.InstanceId

        $Config.IETrustedDomains += $IP

        $Key = "EC2 " + $Name + " NodeManager " + $ID
        $Url = $IP + ":7001/console"
        $Config.NomisShortcuts.Add($Key, ("http://" + $Url))
        $Config.IECompatibilityModeSiteList += $Url
        Write-Output " - Adding $Key $Url to Nomis Shortcuts"

        $Key = "EC2 " + $Name + " Nomis " + $ID
        $Url = $IP + ":7777/forms/frmservlet?config=tag"
        $Config.NomisShortcuts.Add($Key, ("http://" + $Url))
        $Config.IECompatibilityModeSiteList += $Url
        Write-Output " - Adding $Key $Url to Nomis Shortcuts"
      }
    }
  }
}

function Add-Java6 {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  if (Test-Path "C:\Program Files (x86)\Java\jre6") {
    Write-Output "JRE6 already installed"
  } else {
    $TempPath = [System.IO.Path]::GetTempPath()
    Write-Output "Installing JRE6"
    Set-Location -Path $TempPath
    Write-Output " - Downloding installer from S3 bucket"
    Read-S3Object -BucketName $Config.JavaS3Bucket -Key ($Config.JavaS3Folder + "/jre-6u33-windows-i586.exe") -File ".\jre-6u33-windows-i586.exe" | Out-Null
    Write-Output " - Installing JRE6 jre-install.log file in $TempPath"
    Start-Process -Wait -Verbose -FilePath .\jre-6u33-windows-i586.exe -ArgumentList "/s", "/L .\jre-install.log"
    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files (x86)\Java\jre6", [System.EnvironmentVariableTarget]::Machine) | Out-Null
    [System.Environment]::SetEnvironmentVariable("Path", $env:Path + ";%JAVA_HOME%\bin", [System.EnvironmentVariableTarget]::Machine) | Out-Null
  }
}

function Add-Java6NomisWebUtils {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  if (!(Test-Path ("C:\Program Files (x86)\Java\jre6\" + $Config.JavaNomisWebUtilsS3Object + ".installed"))) {
    $TempPath = [System.IO.Path]::GetTempPath()
    Set-Location -Path $TempPath
    Write-Output "Installing Java6NomisWebUtils"
    Write-Output " - Downloding zip from S3 bucket"
    Read-S3Object -BucketName $Config.JavaS3Bucket -Key ($Config.JavaS3Folder + "/" + $Config.JavaNomisWebUtilsS3Object) -File (".\" + $Config.JavaNomisWebUtilsS3Object) | Out-Null
    Write-Output " - Extracing zip"
    Expand-Archive -Path (".\" + $Config.JavaNomisWebUtilsS3Object -DestinationPath "C:\Program Files (x86)\Java\jre6\bin" -Force
    New-Item ("C:\Program Files (x86)\Java\jre6\" + $Config.JavaNomisWebUtilsS3Object + ".installed")
  }

  $newNomisWebUtils = "C:\Program Files (x86)\Java\jre6\bin"
  $oldNomisWebUtils = [System.Environment]::GetEnvironmentVariable ("NOMISWEBUTILS")
  if ($oldNomisWebUtils -ne $newNomisWebUtils) {
    Write-Output "Setting NOMISWEBUTILS environment variable"
    [System.Environment]::SetEnvironmentVariable("NOMISWEBUTILS", $newNomisWebUtils, [System.EnvironmentVariableTarget]::Machine)
    #[System.Environment]::SetEnvironmentVariable("NOMISWEBUTILS", $newNomisWebUtils, [System.EnvironmentVariableTarget]::Process)
    #[System.Environment]::SetEnvironmentVariable("NOMISWEBUTILS", $newNomisWebUtils, [System.EnvironmentVariableTarget]::User)
  }
}

function Add-JavaDeployment {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  # Copy deployment config files
  $DeploymentFolder = "C:\Windows\Sun\Java\Deployment"
  Write-Output "Updating Java deployment config in $DeploymentFolder"
  New-Item -Path $DeploymentFolder -ItemType Directory -Force | Out-Null
  Read-S3Object -BucketName $Config.JavaS3Bucket -Key ($Config.JavaS3Folder + "/deployment.config") -File "$DeploymentFolder\deployment.config" | Out-Null
  Read-S3Object -BucketName $Config.JavaS3Bucket -Key ($Config.JavaS3Folder + "/deployment.properties") -File "$DeploymentFolder\deployment.properties" | Out-Null
  Read-S3Object -BucketName $Config.JavaS3Bucket -Key ($Config.JavaS3Folder + "/trusted.certs") -File "$DeploymentFolder\trusted.certs" | Out-Null
}

function Remove-JavaUpdateCheck {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  # Prevent Java update check
  $ErrorActionPreference = "Continue" # continue if JavaPath not found
  Write-Output "Checking JavaUpdateCheck"
  $JavaPath = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run"
  $ValueName = "SunJavaUpdateSched"
  $Properties = Get-ItemProperty -Path $JavaPath
  if ($Properties) {
    if ($Properties.PSObject.Properties.Name -contains $ValueName) {
      Write-Output " - Removing $JavaPath $ValueName"
      Remove-ItemProperty -Path $JavaPath -Name $ValueName -Force
    }
  }
}

function Add-EdgeConfig {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  $RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge"

  # Turn off Edge first run experience
  Write-Output "Updating Edge Config $RegPath"
  New-Item -Path $RegPath -Force | Out-Null
  New-ItemProperty -Path $RegPath -Name HideFirstRunExperience -Value 1 -PropertyType DWORD -Force | Out-Null

  # Turn on Edge IE Mode using RegPath from previous step
  New-ItemProperty -Path $RegPath -Name InternetExplorerIntegrationLevel -Value 1 -PropertyType DWORD -Force | Out-Null

  # Allow popups for .justice.gov.uk urls
  $RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\PopupsAllowedForUrls"
  New-Item -Path $RegPath -Force | Out-Null
  New-ItemProperty -Path $RegPath -Name 1 -Value "[*.]justice.gov.uk" -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $RegPath -Name 1 -Value "10.*" -PropertyType String -Force | Out-Null
}

function Add-EdgeIECompatibility {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  Write-Output "Adding Edge IE Compatibility Mode"

  $XmlDoc = New-Object System.Xml.XmlDocument
  $Root = $XmlDoc.CreateElement("site-list")
  $Root.SetAttribute('version', 1) | Out-Null
  $XmlDoc.AppendChild($Root) | Out-Null
  $CreatedByElement = $XmlDoc.CreateElement("created-by")
  $ToolElement = $XmlDoc.CreateElement("tool")
  $VersionElement = $XmlDoc.CreateElement("version")
  $DateCreatedElement = $XmlDoc.CreateElement("date_created")
  $ToolElement.InnerText = "EMIESiteListManager"
  $VersionElement.InnerText = "10.0.0.0"
  $DateCreatedElement.InnerText = $(Get-Date -Format "MM/dd/yyyy hh:mm:ss")
  $CreatedByElement.AppendChild($ToolElement) | Out-Null
  $CreatedByElement.AppendChild($VersionElement) | Out-Null
  $CreatedByElement.AppendChild($DateCreatedElement) | Out-Null
  $Root.AppendChild($CreatedByElement) | Out-Null

  foreach ($site in $Config.IECompatibilityModeSiteList) {
    Write-Output " - Adding $site"
    $SiteElement = $XmlDoc.CreateElement("site")
    $SiteElement.SetAttribute('url', $site) | Out-Null
    $CompatModeElement = $XmlDoc.CreateElement("compat-mode")
    $OpenInElement = $XmlDoc.CreateElement("open-in")
    $OpenInElement.SetAttribute('allow-redirect', 'true')
    $CompatModeElement.InnerText = "Default"
    $OpenInElement.InnerText = "IE11"
    $SiteElement.AppendChild($CompatModeElement) | Out-Null
    $SiteElement.AppendChild($OpenInElement) | Out-Null
    $Root.AppendChild($SiteElement) | Out-Null
  }

  $XmlDoc.Save($Config.CompatibilitySiteListPath) | Out-Null

  # Add compatibility list to registry
  New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Edge" -Name InternetExplorerIntegrationSiteList -Value $Config.CompatibilitySiteListPath -PropertyType String -Force | Out-Null
}

function Add-EdgeTrustedSites {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  Write-Output "Add Edge Trusted Sites"
  $Domains = $Config.IETrustedDomains

  # The jumpserver is using IE Enhanced Security so each domain needs to be explicitly added to the following
  # - Registry to allow certain domains to Bypass Enhanced Security (see below)
  # - Trusted Sites - HKCU, HKLM does not apply since the machine is not on the domain
  # NOTE: https:// traffic ONLY is allowed, these settings are external to this environment and are not managed by this script

  $RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\EnhanceSecurityModeBypassListDomains"

  # Ensure the registry path exists
  if (!(Test-Path $RegistryPath)) {
    New-Item -Path $RegistryPath -Force | Out-Null
  }

  # Add each domain to the exclusion list for IE Enhanced Security
  # NOTE: subdomains are automatically included
  for ($i = 0; $i -lt $Domains.Length; $i++) {
    $Index = $i + 1
    $Value = $Domains[$i] -replace '^\*\.', ''

    Write-Output " - Adding $Value to IE Enhanced Security exclusion list"
    New-Item -Path "$RegistryPath\$Index" -Force | Out-Null
    New-ItemProperty -Path "$RegistryPath\$Index" -Name "(Default)" -Value $Value -PropertyType String -Force | Out-Null
  }

  # Add each domain to the trusted sites list
  $Paths = @(
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains"
  )

  foreach ($Path in $Paths) {
    $Domains | ForEach-Object {
      New-Item -Path $Path\$_ -Force | Out-Null
      New-ItemProperty -Path $Path\$_ -Name https -Value 2 -PropertyType DWORD -Force | Out-Null
    }
  }

  # Use Local Machine settings for Internet Security Settings
  $RegPath = "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\Internet Settings"

  if (!(Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
  }

  New-ItemProperty -Path $RegPath -Name Security_HKLM_only -Value 1 -PropertyType DWORD -Force | Out-Null
}

function Add-SQLDeveloper {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  if (Test-Path "C:\Program Files\Oracle\sqldeveloper\sqldeveloper.exe") {
    Write-Output "SQL Developer already installed"
  } else {
    Write-Output "Add SQL Developer"
    Set-Location -Path ([System.IO.Path]::GetTempPath())
    Read-S3Object -BucketName $Config.SQLDeveloperS3Bucket -Key ($Config.SQLDeveloperS3Folder + "/sqldeveloper-22.2.1.234.1810-x64.zip") -File .\sqldeveloper-22.2.1.234.1810-x64.zip | Out-Null

    # Extract SQL Developer - there is no installer for this application
    Expand-Archive -Path .\sqldeveloper-22.2.1.234.1810-x64.zip -DestinationPath "C:\Program Files\Oracle" -Force | Out-Null

    # Create a desktop shortcut
    Write-Output " - Creating StartMenu Link"
    $Shortcut = New-Object -ComObject WScript.Shell
    $SourcePath = Join-Path -Path ([environment]::GetFolderPath("CommonStartMenu")) -ChildPath "\\SQL Developer.lnk"
    $ShortcutLink = $Shortcut.CreateShortcut($SourcePath)
    $ShortcutLink.TargetPath = "C:\Program Files\Oracle\sqldeveloper\sqldeveloper.exe"
    $ShortcutLink.Save() | Out-Null
  }
}

function Add-DnsSuffixSearchList {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  Write-Output "Setting DNS SuffixSearchList"
  $Config.DnsSuffixSearchList
  Set-DnsClientGlobalSetting -SuffixSearchList $Config.DnsSuffixSearchList | Out-Null
}

function Add-NomisShortcuts {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  Write-Output "Add Nomis Shortcuts"
  Write-Output " - Removing existing shortcuts"
  $SourcePath = [environment]::GetFolderPath("CommonStartMenu")
  Get-ChildItem "${SourcePath}/*Nomis*" | ForEach-Object { Join-Path -Path $SourcePath -ChildPath $_.Name | Remove-Item }

  foreach ($Shortcut in $Config.NomisShortcuts.GetEnumerator()) {
    $Name = $Shortcut.Name
    $Url = $Shortcut.Value
    Write-Output " - Add $Name $Url"
    $Shortcut = New-Object -ComObject WScript.Shell
    $SourcePath = Join-Path -Path ([environment]::GetFolderPath("CommonStartMenu")) -ChildPath "\\$Name.url"
    $SourceShortcut = $Shortcut.CreateShortcut($SourcePath)
    $SourceShortcut.TargetPath = $Url
    $SourceShortcut.Save()
  }
}

function Add-MicrosoftOffice {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  $ErrorActionPreference = "Continue" # continue if the dependencies fail to install
  Write-Output "Install Microsoft Office"
  choco install -y microsoft-office-deployment
}

function Remove-StartMenuShutdownOption {
  [CmdletBinding()]
  param (
    [hashtable]$Config
  )

  Write-Output "Remove StartMenu Shutdown Option"
  $RegistryStartMenuPath = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\Start\"
  if (Test-Path -Path $RegistryStartMenuPath) {
    Write-Output "Hiding Restart and Shutdown from Start Menu"
    Set-ItemProperty -Path "$($RegistryStartMenuPath)HideRestart" -Name "value" -Value 1
    Set-ItemProperty -Path "$($RegistryStartMenuPath)HideShutDown" -Name "value" -Value 1
  }
}

<#
.DESCRIPTION
  Retrieves the tags from the instance and returns them as a hashtable.
.EXAMPLE
  Get-InstanceTags returns the tags $hash.Keys and $hash.Values so you can iterate over them.
  foreach ($tag in Get-Tags) {
    Write-Output "Key: $($tag.Key) Value: $($tag.Value)"
  }
#>
function Get-InstanceTags {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = $TagsRaw | ConvertFrom-Json
  $Tags.Tags
}

<#
.DESCRIPTION
  Retrieves the value of a tag from the instance and runs the command with the arguments specified in the tag value.
.EXAMPLE
  Get-PowerShellCommandFromTag -Command Install-WindowsFeature
.NOTES
  Terraform tags need to look something like this:
  "Install-WindowsFeature" = "RDS-RD-Server:RDS-WEB-Access"
  This will run the command Install-WindowsFeature RDS-RD-Server and Install-WindowsFeature RDS-WEB-Access
  The tag value cannot contain spaces or commas as these will fail terraform tag schema checks.
#>
function Get-PowerShellCommandFromTag {
  [CmdletBinding()]
  param (
    [String]$Command
  )

  $matchFound = $false

  foreach ($Tag in Get-InstanceTags) {
    if ($Tag.key -eq $Command) {
      $matchFound = $true
      $argList = $Tag.Value.Split(':')
      foreach ($Arg in $argList) {
          $CommandString = $Command + " " + $Arg
          Write-Host "Running command: $CommandString"
          Invoke-Expression $CommandString
      }
    }
  }

  if (-not $matchFound) {
    Write-Host "No matching instance tags exist locally for $Command"
  }
}

# join domain if domain-name tag is set
$ErrorActionPreference = "Continue"
Import-Module ModPlatformAD -Force
$ADConfig = Get-ModPlatformADConfig
if ($null -ne $ADConfig) {
  $ADCredential = Get-ModPlatformADJoinCredential -ModPlatformADConfig $ADConfig
  if (Add-ModPlatformADComputer -ModPlatformADConfig $ADConfig -ModPlatformADCredential $ADCredential) {
    Exit 3010 # triggers reboot if running from SSM Doc
  } 
} else {
  Write-Output "No domain-name tag found so apply Local Group Policy"
  . .\LocalGroupPolicy.ps1
}

$ErrorActionPreference = "Stop"
$ScriptDir = Get-Location
$Config = Get-Config
Add-EC2InstanceToConfig $Config
Add-Java6 $Config
Add-JavaDeployment $Config
Add-Java6NomisWebUtils $Config
Remove-JavaUpdateCheck $Config
Add-EdgeConfig $Config
Add-EdgeIECompatibility $Config
Add-EdgeTrustedSites $Config
Add-SQLDeveloper $Config
Add-DnsSuffixSearchList $Config
Add-NomisShortcuts $Config
Remove-StartMenuShutdownOption $Config
Get-PowerShellCommandFromTag -Command Install-WindowsFeature 
Add-MicrosoftOffice $Config
Set-Location $ScriptDir
. ../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1
