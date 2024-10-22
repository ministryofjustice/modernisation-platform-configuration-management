$GlobalConfig = @{
    "all"                                    = @{
        "WindowsClientS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
        "WindowsClientS3Folder" = "hmpps/onr"
        "OracleClientS3File"    = "WINDOWS.X64_193000_client.zip" # Oracle 19c client SW, install 1st
        "ORACLE_HOME"           = "E:\app\oracle\product\19.0.0\client_1"
        "ORACLE_BASE"           = "E:\app\oracle"
        "IPSS3File"             = "51054935.ZIP" # Information Platform Services 4.2 SP9 Patch 0
        "DataServicesS3File"    = "DS4214P_11-20011165.exe" # Data Services 4.2 SP14 Patch 11
        "LINK_DIR"              = "E:\SAP BusinessObjects\Data Services"
        "BIP_INSTALL_DIR"       = "E:\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0"
        "RegistryPath"          = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon"
        "LegalNoticeCaption"    = "IMPORTANT"
        "LegalNoticeText"       = "This system is restricted to authorized users only. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information"
    }
    "oasys-national-reporting-development"   = @{
        "OnrShortcuts" = @{
        }
    }
    "oasys-national-reporting-test"          = @{
        "sysDbName"       = "T2BOSYS"
        "audDbName"       = "T2BOAUD"
        "tnsorafile"      = "tnsnames_T2_BODS.ora"
        "cmsMainNode"     = "t2-tst-bods-asg" #TODO: change this BACK
        "cmsExtendedNode" = "t2-onr-bods-2"
        "serviceUser"     = "svc_nart"
        "serviceUserPath" = "OU=Service,OU=Users,OU=NOMS RBAC,DC=AZURE,DC=NOMS,DC=ROOT"
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
        "serviceUserDescription" = "Onr BODS T2 service user for AWS"
        "domain"    = "AZURE"
    }
    "oasys-national-reporting-preproduction" = @{
        "sysDbName"       = "PPBOSYS"
        "audDbName"       = "PPBOAUD"
        "tnsorafile"      = "tnsnames_PP_BODS.ora"
        "cmsMainNode"     = "pp-onr-bods-1"
        "cmsExtendedNode" = "pp-onr-bods-2"
        "serviceUser"     = "svc_nart"
        "serviceUserPath" = "OU=SERVICE_ACCOUNTS,OU=RBAC,DC=AZURE,DC=HMPP,DC=ROOT"
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT"
        "serviceUserDescription" = "Onr BODS preprod service user for AWS"
        "domain" = "HMPP"
    }
    "oasys-national-reporting-production"    = @{
        "domain" = "HMPP"
     }
}

$tempPath = ([System.IO.Path]::GetTempPath())

$ConfigurationManagementRepo = "$tempPath\modernisation-platform-configuration-management"
$ErrorActionPreference = "Stop"
$WorkingDirectory = "D:\Software"
$AppDirectory = "E:\App"

# # Path to ebsnvme-id.exe
# $ebsNvmeIdPath = "C:\ProgramData\Amazon\Tools\ebsnvme-id.exe"

# # Get the mapping of Disk Numbers to Device Names
# $diskMappings = @{}

# # Run ebsnvme-id.exe and parse the output
# $ebsOutput = & $ebsNvmeIdPath | Out-String

# # Process the output
# $entries = $ebsOutput -split "(?m)^\s*$" | Where-Object { $_ -match "Disk Number" }

# foreach ($entry in $entries) {
#     $lines = $entry -split "`n"
#     $diskNumber = $null
#     $volumeId = $null
#     $deviceName = $null

#     foreach ($line in $lines) {
#         if ($line -match "^Disk Number:\s+(\d+)") {
#             $diskNumber = [int]$Matches[1]
#         } elseif ($line -match "^Volume ID:\s+(\S+)") {
#             $volumeId = $Matches[1]
#         } elseif ($line -match "^Device Name:\s+(\S+)") {
#             $deviceName = $Matches[1]
#         }
#     }

#     if ($deviceName) {
#         $diskMappings[$deviceName] = @{
#             DiskNumber = $diskNumber
#             VolumeId = $volumeId
#         }
#     }
# }

# # Define the desired mappings
# $desiredMappings = @{
#     "/dev/xvdk" = @{
#         DriveLetter = 'D'
#         Label = 'Temp'
#     }
#     "/dev/xvdl" = @{
#         DriveLetter = 'E'
#         Label = 'App'
#     }
#     "/dev/xvdm" = @{
#         DriveLetter = 'F'
#         Label = 'Storage'
#     }
# }

# foreach ($deviceName in $diskMappings.Keys) {
#     if ($desiredMappings.ContainsKey($deviceName)) {
#         $diskInfo = $diskMappings[$deviceName]
#         $diskNumber = $diskInfo.DiskNumber
#         $driveLetter = $desiredMappings[$deviceName].DriveLetter
#         $label = $desiredMappings[$deviceName].Label

#         Write-Host "Processing Disk Number: $diskNumber (Device Name: $deviceName), assigning $driveLetter`: labeled '$label'"

#         # Initialize the disk if it's not initialized
#         $disk = Get-Disk -Number $diskNumber -ErrorAction Stop
#         if ($disk.PartitionStyle -eq 'RAW') {
#             # Initialize the disk with GPT partition style
#             Initialize-Disk -Number $diskNumber -PartitionStyle GPT -Confirm:$false
#             Start-Sleep -Seconds 2
#         }

#         # Create a new partition if no partitions exist
#         $partitions = Get-Partition -DiskNumber $diskNumber
#         if ($partitions.Count -eq 0) {
#             $partition = New-Partition -DiskNumber $diskNumber -UseMaximumSize -IsActive:$true
#             Start-Sleep -Seconds 2
#         } else {
#             $partition = $partitions[0]
#         }

#         # Format the partition if it's not formatted
#         $volume = Get-Volume -DiskNumber $diskNumber | Where-Object { $_.FileSystem -ne "NTFS" }
#         if ($volume) {
#             Format-Volume -Partition $partition -FileSystem NTFS -NewFileSystemLabel $label -Confirm:$false
#             Start-Sleep -Seconds 2
#         } else {
#             # Change the label if necessary
#             $volume = Get-Volume -DiskNumber $diskNumber
#             if ($volume.FileSystemLabel -ne $label) {
#                 Set-Volume -DriveLetter $volume.DriveLetter -NewFileSystemLabel $label
#             }
#         }

#         # Assign the drive letter
#         $currentDriveLetter = $partition.DriveLetter
#         if ($currentDriveLetter -ne $driveLetter) {
#             Assign-Partition -DiskNumber $diskNumber -PartitionNumber $partition.PartitionNumber -DriveLetter $driveLetter
#         }

#         Write-Host "Disk $diskNumber initialized and formatted. Drive Letter: $driveLetter, Label: $label"
#     } else {
#         Write-Host "Device Name: $deviceName does not have a desired mapping. Skipping."
#     }
# }


# {{{ functions
function Get-Config {
    $tokenParams = @{
        TimeoutSec = 10
        Headers    = @{"X-aws-ec2-metadata-token-ttl-seconds" = 3600}
        Method     = 'PUT'
        Uri        = 'http://169.254.169.254/latest/api/token'
    }
    $Token = Invoke-RestMethod @tokenParams

    $instanceIdParams = @{
        TimeoutSec = 10
        Headers    = @{"X-aws-ec2-metadata-token" = $Token}
        Method     = 'GET'
        Uri        = 'http://169.254.169.254/latest/meta-data/instance-id'
    }
    $InstanceId = Invoke-RestMethod @instanceIdParams

    $awsParams = @(
        'ec2',
        'describe-tags',
        '--filters',
        "Name=resource-id,Values=$InstanceId"
    )

    $TagsRaw = & aws @awsParams

    $Tags = $TagsRaw | ConvertFrom-Json
    $EnvironmentNameTag = ($Tags.Tags | Where-Object { $_.Key -eq "environment-name" }).Value

    if (-not $GlobalConfig.Contains($EnvironmentNameTag)) {
        Write-Error "Unexpected environment-name tag value $EnvironmentNameTag"
    }

    Return $GlobalConfig.all + $GlobalConfig[$EnvironmentNameTag]
}

function Get-Installer {
    param (
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $s3Params = @{
        BucketName = $Config.WindowsClientS3Bucket
        Key        = ($Config.WindowsClientS3Folder + "/" + $Key)
        File       = $Destination
        Verbose    = $true
    }

    Read-S3Object @s3Params
}

function Get-SecretValue {
    param (
        [Parameter(Mandatory)]
        [string]$SecretId,
        [Parameter(Mandatory)]
        [string]$SecretKey
    )

    try {
        $secretJson = aws secretsmanager get-secret-value --secret-id $SecretId --query SecretString --output text

        if ($null -eq $secretJson -or $secretJson -eq '') {
            Write-Host "The SecretId '$SecretId' does not exist or returned no value."
            return $null
        }

        $secretObject = $secretJson | ConvertFrom-Json

        if (-not $secretObject.PSObject.Properties.Name -contains $SecretKey) {
            Write-Host "The SecretKey '$SecretKey' does not exist in the secret."
            return $null
        }

        return $secretObject.$SecretKey
    }
    catch {
        Write-Host "An error occurred while retrieving the secret: $_"
        return $null
    }
}


function Get-InstanceTags {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = $TagsRaw | ConvertFrom-Json
  $Tags.Tags
}

function Clear-PendingFileRenameOperations {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    $regKey = "PendingFileRenameOperations"

    if (Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction SilentlyContinue) {
        try {
            Remove-ItemProperty -Path $regPath -Name $regKey -Force -ErrorAction Stop
            Write-Host "Successfully removed $regKey from the registry."
        }
        catch {
            Write-Warning "Failed to remove $regKey. Error: $_"
        }
    }
    else {
        Write-Host "$regKey does not exist in the registry. No action needed."
    }
}

# Function to change drive label
function Set-DriveLabel {
    param (
        [Parameter(Mandatory=$true)]
        [string]$DriveLetter,

        [Parameter(Mandatory=$true)]
        [string]$NewLabel
    )

    # Remove colon from drive letter if present
    $DriveLetter = $DriveLetter.TrimEnd(':')

    try {
        # Change the drive label
        Set-Volume -DriveLetter $DriveLetter -NewFileSystemLabel $NewLabel
        Write-Host "Drive $DriveLetter label changed to '$NewLabel' successfully."
    }
    catch {
        Write-Error "Failed to change drive label: $_"
    }
}

function Test-DatabaseConnection {
    param (
        [Parameter(Mandatory=$true)]
        [String]$typePath,
        [Parameter(Mandatory=$true)]
        [String]$tnsName,
        [Parameter(Mandatory=$true)]
        [String]$username,
        [Parameter(Mandatory=$true)]
        [String]$password
    )

    Add-Type -Path $typePath

    $connectionString = "User Id=$username;Password=$password;Data Source=$tnsName"
    $connection = New-Object Oracle.DataAccess.Client.OracleConnection($connectionString)

    try {
        $connection.Open()
        Write-Host "Connection successful!"
        $connection.Close()
        return 0
    } catch {
        Write-Host "Connection failed: $($_.Exception.Message)"
        return 1
    }
}

function Get-ChildProcessIds {
    param ($ParentId)
    $childProcesses = Get-CimInstance Win32_Process -Filter "ParentProcessId=$ParentId"
    foreach ($child in $childProcesses) {
        $child.ProcessId
        Get-ChildProcessIds -ParentId $child.ProcessId
    }
}

function Move-ModPlatformADComputer {
    [CmdletBinding()]
    param (
      [Parameter(Mandatory=$true)][System.Management.Automation.PSCredential]$ModPlatformADCredential,
      [Parameter(Mandatory=$true)][string]$NewOU
    )

    $ErrorActionPreference = "Stop"

      # Do nothing if host not part of domain
  if (-not (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
    Return $false
  }

  # Install powershell features if missing
  if (-not (Get-Module -ListAvailable -Name "ActiveDirectory")) {
    Write-Host "INFO: Installing RSAT-AD-PowerShell feature"
    Install-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature
  }

  # Move the computer to the new OU
  (Get-ADComputer -Credential $ModPlatformADCredential -Identity $env:COMPUTERNAME).objectGUID | Move-ADObject -TargetPath $NewOU -Credential $ModPlatformADCredential
}
# }}}

# {{{ Prep the server for installation
# Set the registry key to prefer IPv4 over IPv6
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 0x20 -Type DWord

# Output a message to confirm the change
Write-Host "Registry updated to prefer IPv4 over IPv6. A system restart is required for changes to take effect."

# Turn off the firewall as this will possibly interfere with Sia Node creation
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Disable antivirus and other security during installation

# Disable real-time monitoring
Set-MpPreference -DisableRealtimeMonitoring $true

# Disable intrusion prevention system
Set-MpPreference -DisableIntrusionPreventionSystem $true

# Disable script scanning
Set-MpPreference -DisableScriptScanning $true

# Disable behavior monitoring
Set-MpPreference -DisableBehaviorMonitoring $true

Write-Host "Windows Security antivirus has been disabled. Please re-enable it as soon as possible for security reasons."

# Label the drives just to add some convienience
Set-DriveLabel -DriveLetter "D" -NewLabel "Temp"
Set-DriveLabel -DriveLetter "E" -NewLabel "App"
Set-DriveLabel -DriveLetter "F" -NewLabel "Storage"

# Set local time zone to UK
Set-TimeZone -Name "GMT Standard Time"

# }}} complete - add prerequisites to server

# {{{ join domain if domain-name tag is set
# Join domain and reboot is needed before installers run
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
# }}}

# {{{ Get the config and tags for the instance
$Config = Get-Config
$Tags = Get-InstanceTags
# }}}

# {{{ Add service user to domain, allow service user to RDP into machine
# re-importing this if the machine has been rebooted, probably not needed
Import-Module ModPlatformAD -Force
$ADConfig = Get-ModPlatformADConfig
$ADCredential = Get-ModPlatformADJoinCredential -ModPlatformADConfig $ADConfig
$ComputerName = $env:COMPUTERNAME

$dbenv = ($Tags | Where-Object { $_.Key -eq "oasys-national-reporting-environment" }).Value
$bodsSecretName  = "/sap/bods/$dbenv/passwords"

$serviceUserPlainTextPassword = Get-SecretValue -SecretId $bodsSecretName -SecretKey $($Config.serviceUser)
$serviceUserPassword = ConvertTo-SecureString -String $serviceUserPlainTextPassword -AsPlainText -Force

New-ModPlatformADUser -Name $($Config.serviceUser) -Path $($Config.serviceUserPath) -Description $($Config.serviceUserDescription) -accountPassword $serviceUserPassword -ModPlatformADCredential $ADCredential

Enable-PSRemoting -Force

# Use admin credentials to add the service user to the Remote Desktop Users group
$ADAdminCredential = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig -ModPlatformADSecret $ADSecret

$serviceUser = "$($Config.domain)\$($Config.serviceUser)"
Write-Host "Adding $serviceUser to Remote Desktop Users group on $ComputerName"

Invoke-Command -ComputerName $ComputerName -Credential $ADAdminCredential -ScriptBlock {
   param($serviceUser)
   #Add the service user to the Remote Desktop Users group locally, if this isn't enough change to -Group Administrators
   Add-LocalGroupMember -Group "Remote Desktop Users" -Member $serviceUser
   Add-LocalGroupMember -Group "Administrators" -Member $serviceUser
} -ArgumentList $serviceUser

# Move the computer to the correct OU
Move-ModPlatformADComputer -ModPlatformADCredential $ADAdminCredential -NewOU $($Config.nartComputersOU)

# ensure computer is in the correct OU
gpupdate /force
# }}}

# {{{ prepare assets
New-Item -ItemType Directory -Path $WorkingDirectory -Force
New-Item -ItemType Directory -Path $AppDirectory -Force

Set-Location -Path $WorkingDirectory
Get-Installer -Key $Config.OracleClientS3File -Destination (".\" + $Config.OracleClientS3File)
Get-Installer -Key $Config.IPSS3File -Destination (".\" + $Config.IPSS3File)
Get-Installer -Key $Config.DataServicesS3File -Destination (".\" + $Config.DataServicesS3File)

Expand-Archive ( ".\" + $Config.OracleClientS3File) -Destination ".\OracleClient"
Expand-Archive ( ".\" + $Config.IPSS3File) -Destination ".\IPS"
# }}}

# {{{ Install Oracle Client
# documentation: https://docs.oracle.com/en/database/oracle/oracle-database/19/ntcli/running-oracle-universal-installe-using-the-response-file.html

# Create response file for silent install
$oracleClientResponseFileContent = @"
oracle.install.responseFileVersion=/oracle/install/rspfmt_clientinstall_response_schema_v19.0.0
ORACLE_HOME=$($Config.ORACLE_HOME)
ORACLE_BASE=$($Config.ORACLE_BASE)
oracle.install.IsBuiltInAccount=true
oracle.install.client.installType=Administrator
"@

$oracleClientResponseFileContent | Out-File -FilePath "$WorkingDirectory\OracleClient\client\client_install.rsp" -Force -Encoding ascii

# Service user will have been added by Group Policy to the Administrators User Group, makes sure this is applied
gpupdate /force

# convert the service user password and domain to a credential object
$serviceUserCredentialObject = New-Object System.Management.Automation.PSCredential -ArgumentList "$($Config.domain)\$($Config.serviceUser)", $serviceUserPassword 

# Install Oracle Client silent install
$OracleClientInstallParams = @{
    FilePath         = "$WorkingDirectory\OracleClient\client\setup.exe"
    WorkingDirectory = "$WorkingDirectory\OracleClient\client"
    ArgumentList     = "-silent -noconfig -nowait -responseFile $WorkingDirectory\OracleClient\client\client_install.rsp"
    Wait             = $true
    NoNewWindow      = $true
    Credential       = $serviceUserCredentialObject
}

Start-Process @OracleClientInstallParams

# Copy tnsnames.ora file to correct location
Copy-Item -Path "$ConfigurationManagementRepo\powershell\Configs\$($Config.tnsorafile)" -Destination "$($Config.ORACLE_HOME)\network\admin\tnsnames.ora" -Force

# Install Oracle configuration tools
$oracleConfigToolsParams = @{
    FilePath         = "$WorkingDirectory\OracleClient\client\setup.exe"
    WorkingDirectory = "$WorkingDirectory\OracleClient\client"
    ArgumentList     = "-executeConfigTools -silent -nowait -responseFile $WorkingDirectory\OracleClient\client\client_install.rsp"
    Wait             = $true
    NoNewWindow      = $true
    Credential       = $serviceUserCredentialObject
}

Start-Process @oracleConfigToolsParams

[Environment]::SetEnvironmentVariable("ORACLE_HOME", $Config.ORACLE_HOME, [System.EnvironmentVariableTarget]::Machine)

# }}}

# {{{ install IPS
$Tags = Get-InstanceTags

# set Secret Names based on environment
$dbenv = ($Tags | Where-Object { $_.Key -eq "oasys-national-reporting-environment" }).Value
$siaNodeName = (($Tags | Where-Object { $_.Key -eq "Name" }).Value).Replace("-", "").ToUpper() # cannot contain hyphens
$bodsSecretName  = "/sap/bods/$dbenv/passwords"
$sysDbSecretName = "/oracle/database/$($Config.sysDbName)/passwords"
$audDbSecretName = "/oracle/database/$($Config.audDbName)/passwords"

# Get secret values, silently continue if they don't exist
$bods_ips_system_owner = Get-SecretValue -SecretId $sysDbSecretName -SecretKey "bods_ips_system_owner" -ErrorAction SilentlyContinue
$bods_ips_audit_owner = Get-SecretValue -SecretId $audDbSecretName -SecretKey "bods_ips_audit_owner" -ErrorAction SilentlyContinue
$bods_cluster_key = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_cluster_key" -ErrorAction SilentlyContinue
$bods_admin_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_admin_password" -ErrorAction SilentlyContinue
$bods_subversion_password = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_subversion_password" -ErrorAction SilentlyContinue
$ips_product_key = Get-SecretValue -SecretId $bodsSecretName -SecretKey "ips_product_key" -ErrorAction SilentlyContinue

# Check database credentials BEFORE installer runs
$typePath = "E:\app\oracle\product\19.0.0\client_1\ODP.NET\bin\4\Oracle.DataAccess.dll"

# Define an array of database configurations
$dbConfigs = @(
    @{
        Name = "$($Config.sysDbName)"
        Username = "bods_ips_system_owner"
        Password = $bods_ips_system_owner
    },
    @{
        Name = "$($Config.audDbName)"
        Username = "bods_ips_audit_owner"
        Password = $bods_ips_audit_owner
    }
)

# Loop through each database configuration
foreach ($db in $dbConfigs) {
    $return = Test-DatabaseConnection -typePath $typePath -tnsName $db.Name -username $db.Username -password $db.Password
    if ($return -ne 0) {
        Write-Host "Connection to $($db.Name) failed. Exiting."
        exit 1
    }
    Write-Host "Connection to $($db.Name) successful."
}

Write-Host "All database connections successful."

# Create response file for IPS silent install
$ipsResponseFileContentCommon = @"
### Choose to integrate Introscope Enterprise Manager: integrate or nointegrate
chooseintroscopeintegration=nointegrate
### Choose to integrate Solution Manager Diagnostics (SMD) Agent: integrate or nointegrate
choosesmdintegration=nointegrate
### CMS cluster key
clusterkey=$bods_cluster_key
### CMS administrator password
cmspassword=$bods_admin_password
### CMS connection port
cmsport=6400
### Existing auditing DB password
existingauditingdbpassword=$bods_ips_audit_owner
### Existing auditing DB server
existingauditingdbserver=$($Config.audDbName)
### Existing auditing DB user name
existingauditingdbuser=bods_ips_audit_owner
### Existing CMS DB password
existingcmsdbpassword=$bods_ips_system_owner
### Existing CMS DB reset flag: 0 or 1 where 1 means don't reset <<<<<<-- check this
existingcmsdbreset=1
### Existing CMS DB server
existingcmsdbserver=$($Config.sysDbName)
### Existing CMS DB user name
existingcmsdbuser=bods_ips_system_owner
### Installation Directory
installdir=E:\SAP BusinessObjects\
### Choose install type: default, custom, webtier
installtype=custom
### LCM server name
lcmname=LCM_repository
### LCM password
lcmpassword=$bods_subversion_password
### LCM port
lcmport=3690
### LCM user name
lcmusername=LCM
### Choose install mode: new, expand where new == first instance of the installation
neworexpandinstall=new
### Product Keycode
productkey=$ips_product_key
### Language Packs Selected to Install
selectedlanguagepacks=en
### Setup UI Language
setupuilanguage=en
### SIA node name
sianame=$siaNodeName
### SIA connector port
siaport=6410
### Tomcat connection port
tomcatconnectionport=28080
### Tomcat redirect port
tomcatredirectport=8443
### Tomcat shutdown port
tomcatshutdownport=8005
### Auditing Database Type
usingauditdbtype=oracle
### CMS Database Type
usingcmsdbtype=oracle
### Features to install
features=JavaWebApps1,CMC.Monitoring,LCM,IntegratedTomcat,CMC.AccessLevels,CMC.Applications,CMC.Audit,CMC.Authentication,CMC.Calendars,CMC.Categories,CMC.CryptographicKey,CMC.Events,CMC.Folders,CMC.Inboxes,CMC.Licenses,CMC.PersonalCategories,CMC.PersonalFolders,CMC.Servers,CMC.Sessions,CMC.Settings,CMC.TemporaryStorage,CMC.UsersAndGroups,CMC.QueryResults,CMC.InstanceManager,CMS,FRS,PlatformServers.AdaptiveProcessingServer,PlatformServers.AdaptiveJobServer,ClientAuditingProxyProcessingService,LCMProcessingServices,MonitoringProcessingService,SecurityTokenService,DestinationSchedulingService,ProgramSchedulingService,Subversion,UpgradeManager,AdminTools
"@

# Create response file for IPS expanded install
$ipsResponseFileContentExtendedNode = @"
### Choose install mode: new, expand where new == first instance of the installation
neworexpandinstall=expand
### Install a new LCM or use an existing LCM
neworexistinglcm=expand
### CMS cluster key
clusterkey=$bods_cluster_key
### CMS administrator password
cmspassword=$bods_admin_password
### CMS connection port
cmsport=6400
### Existing main cms node name
cmsname=$($Config.cmsMainNode)
### Product Keycode
productkey=$ips_product_key
### SIA node name
sianame=$siaNodeName
### SIA connector port
siaport=6410
### Language Packs Selected to Install
selectedlanguagepacks=en
### Setup UI Language
setupuilanguage=en
### Installation Directory
installdir=E:\SAP BusinessObjects\
### Choose install type: default, custom, webtier
installtype=custom
### Choose to integrate Introscope Enterprise Manager: integrate or nointegrate
chooseintroscopeintegration=nointegrate
### Choose to integrate Solution Manager Diagnostics (SMD) Agent: integrate or nointegrate
choosesmdintegration=nointegrate
### Features to install
features=JavaWebApps1,CMC.Monitoring,LCM,IntegratedTomcat,CMC.AccessLevels,CMC.Applications,CMC.Audit,CMC.Authentication,CMC.Calendars,CMC.Categories,CMC.CryptographicKey,CMC.Events,CMC.Folders,CMC.Inboxes,CMC.Licenses,CMC.PersonalCategories,CMC.PersonalFolders,CMC.Servers,CMC.Sessions,CMC.Settings,CMC.TemporaryStorage,CMC.UsersAndGroups,CMC.QueryResults,CMC.InstanceManager,CMS,FRS,PlatformServers.AdaptiveProcessingServer,PlatformServers.AdaptiveJobServer,ClientAuditingProxyProcessingService,LCMProcessingServices,MonitoringProcessingService,SecurityTokenService,DestinationSchedulingService,ProgramSchedulingService,Subversion,UpgradeManager,AdminTools
"@

$instanceName = ($Tags | Where-Object { $_.Key -eq "Name" }).Value
$ipsInstallIni = "$WorkingDirectory\IPS\DATA_UNITS\IPS_win\ips_install.ini"

if ($instanceName -eq $($Config.cmsMainNode)) {
    $ipsResponseFileContentCommon | Out-File -FilePath "$ipsInstallIni" -Force -Encoding ascii
} elseif ($instanceName -eq $($Config.cmsExtendedNode)) {
    $ipsResponseFileContentExtendedNode | Out-File -FilePath "$ipsInstallIni" -Force -Encoding ascii
} else {
    Write-Output "Unknown node type, cannot create response file"
    exit 1
}

Clear-PendingFileRenameOperations

$setupExe = "$WorkingDirectory\IPS\DATA_UNITS\IPS_win\setup.exe"

# Build the command to pass to cmd.exe
# $command = 'start "" /wait "' + $setupExe + '" -r "' + $ipsInstallIni + '"'

# Build the ArgumentList as an array of strings
# $cmdArgs = @('/c', $command)

# $command | Out-File -FilePath "$WorkingDirectory\IPS\DATA_UNITS\IPS_win\command.txt" -Force

if (-NOT(Test-Path $setupExe)) {
    Write-Host "IPS setup.exe not found at $($setupExe)"
    exit 1
}

if (-NOT(Test-Path $ipsInstallIni)) {
    Write-Host "IPS response file not found at $ipsInstallIni"
    exit 1
}

$logFile = "$WorkingDirectory\IPS\DATA_UNITS\IPS_win\install_ips_sp.log"
New-Item -Type File -Path $logFile -Force | Out-Null

try {
    "Starting IPS installer at $(Get-Date)" | Out-File -FilePath $logFile -Append
    $process = Start-Process -FilePath "D:\Software\IPS\DATA_UNITS\IPS_win\setup.exe" -ArgumentList '/wait -r D:\Software\IPS\DATA_UNITS\IPS_win\ips_install.ini' -Wait -NoNewWindow -Credential $serviceUserCredentialObject -Verbose -PassThru
    $installProcessId = $process.Id
    "Initial process is $installProcessId at $(Get-Date)" | Out-File -FilePath $logFile -Append
    # get all process IDs to monitor
    $allProcessIds = @($installProcessId)
    do {

        # Refresh the list of child process IDs
        $allProcessIds = @($installProcessId) + (Get-ChildProcessIds -ParentId $installProcessId)

        # Get currently running processes from our list
        $runningProcesses = Get-Process -Id $allProcessIds -ErrorAction SilentlyContinue

        # Log the running processes
        $runningProcessIds = $runningProcesses | ForEach-Object { $_.Id }
        "Running processes at $(Get-Date): $($runningProcessIds -join ', ')" | Out-File -FilePath $logFile -Append

        # Check if the parent process is still running
        $parentStillRunning = Get-Process -Id $installProcessId -ErrorAction SilentlyContinue

        Start-Sleep -Seconds 1

    } while ($runningProcesses -and $parentStillRunning)
    "All monitored processes have completed at $(Get-Date)" | Out-File -FilePath $logFile -Append

    $exitcode = $installProcess.ExitCode
    "IPS install has exited with code $exitcode" | Out-File -FilePath $logFile -Append
    "Stopped IPS installer at $(Get-Date)" | Out-File -FilePath $logFile -Append
} catch {
    $exception = $_.Exception
    "Failed to start installer at $(Get-Date)" | Out-File -FilePath $logFile -Append
    "Exception Message: $($exception.Message)" | OUt-File -FilePath $logFile -Append
    if ($exception.InnerException) {
        "Inner Exception Message: $($exception.InnerException.Message)" | Out-File -FilePath $logFile -Append
    }
}



# TODO: supply password values to argument list OR remove the reponse file after it's been used
# }}} end install IPS

# {{{ install Data Services
[Environment]::SetEnvironmentVariable("LINK_DIR", $Config.LINK_DIR, [System.EnvironmentVariableTarget]::Machine)

if (-NOT(Test-Path "F:\BODS_COMMON_DIR")) {
    Write-Output "Creating F:\BODS_COMMON_DIR"
    New-Item -ItemType Directory -Path "F:\BODS_COMMON_DIR"
}
[Environment]::SetEnvironmentVariable("DS_COMMON_DIR", "F:\BODS_COMMON_DIR", [System.EnvironmentVariableTarget]::Machine)
#
$data_services_product_key = Get-SecretValue -SecretId $bodsSecretName -SecretKey "data_services_product_key" -ErrorAction SilentlyContinue


$dataServicesResponsePrimary = @"
### #property.CMSAUTHENTICATION.description#
cmsauthentication=secEnterprise
### CMS administrator password
cmspassword=$bods_admin_password
### #property.CMSUSERNAME.description#
cmsusername=Administrator
### #property.CMSAuthMode.description#
dscmsauth=secEnterprise
### #property.CMSEnabledSSL.description#
dscmsenablessl=0
### CMS administrator password
dscmspassword=$bods_admin_password
### #property.CMSServerPort.description#
dscmsport=6400
### #property.CMSServerName.description#
dscmssystem=$($Config.cmsMainNode)
### #property.CMSUser.description#
dscmsuser=Administrator
### #property.DSCommonDir.description#
dscommondir=F:\BODS_COMMON_DIR\
### #property.DSConfigCMSSelection.description#
dsconfigcmsselection=install
### #property.DSConfigMergeSelection.description#
dsconfigmergeselection=skip
### #property.DSExistingDSConfigFile.description#
dsexistingdsconfigfile=
### #property.DSInstallTypeSelection.description#
dsinstalltypeselection=Custom
### #property.DSLocalCMS.description#
dslocalcms=true
### #property.DSLoginInfoAccountSelection.description#
dslogininfoaccountselection=this
### #property.DSLoginInfoThisUser.description#
dslogininfothisuser=$($Config.Domain)\$($Config.serviceUser)
### #property.DSLoginInfoThisPassword.description#
dslogininfothispassword=$service_user_password
### Installation folder for SAP products
installdir=E:\SAP BusinessObjects\
### #property.IsCommonDirChanged.description#
iscommondirchanged=1
### #property.MasterCmsName.description#
mastercmsname=$($Config.cmsMainNode)
### #property.MasterCmsPort.description#
mastercmsport=6400
### Keycode for the product.
productkey=$data_services_product_key
### *** property.SelectedLanguagePacks.description ***
selectedlanguagepacks=en
### Available features
features=DataServicesJobServer,DataServicesAccessServer,DataServicesServer,DataServicesDesigner,DataServicesClient,DataServicesManagementConsole,DataServicesEIMServices,DataServicesMessageClient,DataServicesDataDirect,DataServicesDocumentation
"@

$dataServicesResponsePrimary | Out-File -FilePath "$WorkingDirectory\ds_install.ini" -Force -Encoding ascii

$dataServicesInstallParams = @{
    FilePath = "$WorkingDirectory\$($Config.DataServicesS3File)"
    ArgumentList = "-q","-r","$WorkingDirectory\ds_install.ini"
    Wait = $true
    NoNewWindow = $true
    Credential = $serviceUserCredentialObject
}

# Install Data Services
Start-Process @dataServicesInstallParams

# }}} End install Data Services

# {{{ Post install steps for Data Services, configure JDBC driver
$jdbcDriverPath = "$($Config.ORACLE_HOME)\jdbc\lib\ojdbc8.jar"
$destinations = @(
    "$($Config.LINK_DIR)\ext\lib",
    "$($Config.BIP_INSTALL_DIR)\java\lib\im\oracle" #, # uncomment comma and line below if using Data Quality reports
    # "$($Config.BIP_INSTALL_DIR)\warfiles\webapps\DataServices\WEB-INF\lib" # Only needed if using Data Quality reports
)

if (Test-Path $jdbcDriverPath) {
    foreach ($destination in $destinations) {
        if (Test-Path $destination) {
            Write-Output "Copying JDBC driver to $destination"
            Copy-Item -Path $jdbcDriverPath -Destination $destination -NoClobber
        } else {
            Write-Output "Destination $destination does not exist, skipping"
        }
    }
} else {
    Write-Output "JDBC driver not found at $jdbcDriverPath"
    exit 1
}
# Install notes: If using Data Quality reports: Use WDeploy to re-deploy BODS web apps.
#                If not, Restart EIM Adaptive Processing Server via CMC.
# }}}

# {{{ login text
# Apply to all environments that aren't on the domain
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
# }}}
