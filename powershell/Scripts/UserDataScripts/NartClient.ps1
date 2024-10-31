$GlobalConfig = @{
    "all"                                    = @{
        "WindowsClientS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
        "WindowsClientS3Folder" = "hmpps/ncr-packages"
        "OracleClientS3File"    = "WINDOWS.X64_193000_client.zip" # Oracle 19c client SW, install 1st
        "ORACLE_HOME"           = "C:\app\oracle\product\19.0.0\client_1"
        "ORACLE_BASE"           = "C:\app\oracle"
        # "IPSS3File"             = "IPS.ZIP" # IPS SW, install 2nd
        # "DataServicesS3File"    = "DATASERVICES.ZIP" # BODS SW, install 3rd
        "BIPWindowsClient43"    = "BIPLATCLNT4303P_300-70005711.EXE" # Client tool 4.3 SP 3
        "BIPWindowsClient42"    = "BIPLATCLNT4203P_300-70005711.EXE" # Client tool 4.2 SP 3 TODO: check this!
        "RegistryPath"          = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon"
        "LegalNoticeCaption"    = "IMPORTANT"
        "LegalNoticeText"       = "This system is restricted to authorized users only. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information"
    }
    "oasys-national-reporting-development"   = @{ # TODO: change this to hmpps-domain-services-development later on
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
        "NcrShortcuts" = @{
        }
    }
    "oasys-national-reporting-test"          = @{
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
        "NcrShortcuts" = @{
        }
    }
    "oasys-national-reporting-preproduction" = @{
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT"
        "NcrShortcuts" = @{
        }
    }
    "oasys-national-reporting-production"    = @{
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT"
        "NcrShortcuts" = @{
        }
    }
}

$tempPath = ([System.IO.Path]::GetTempPath())
$ConfigurationManagementRepo = "$tempPath\modernisation-platform-configuration-management"
$WorkingDirectory = "C:\Software"
$AppDirectory = "C:\App"

$ErrorActionPreference = "Stop"

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
# }}} end of functions

# {{{ Prep the server for installation
# Set the registry key to prefer IPv4 over IPv6
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 0x20 -Type DWord

# Output a message to confirm the change
Write-Host "Registry updated to prefer IPv4 over IPv6. A system restart is required for changes to take effect."

# Turn off the firewall as this will possibly interfere with Sia Node creation
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False

# Disable antivirus and other security during installation

# Disable real-time monitoring - doesn't exist on Server 2012
# Set-MpPreference -DisableRealtimeMonitoring $true

# Disable intrusion prevention system - doesn't exist on Server 2012
# Set-MpPreference -DisableIntrusionPreventionSystem $true

# Disable script scanning - doesn't exist on Server 2012
# Set-MpPreference -DisableScriptScanning $true

# Disable behavior monitoring - doesn't exist on Server 2012
# Set-MpPreference -DisableBehaviorMonitoring $true

# doesn't exist on Server 2012
# Write-Host "Windows Security antivirus has been disabled. Please re-enable it as soon as possible for security reasons."

# Set local time zone to UK although this should now be set by Group Policy objects
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

# {{{ Add computer to the correct OU
Import-Module ModPlatformAD -Force
$ADConfig = Get-ModPlatformADConfig

# Get the AD Admin credentials
$ADAdminCredential = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig

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
Get-Installer -Key $Config.BIPWindowsClient43 -Destination (".\" + $Config.BIPWindowsClient43)
# TODO: Get BIP 4.2 client tools

Expand-Archive ( ".\" + $Config.OracleClientS3File) -Destination ".\OracleClient"
# }}}

# {{{ Install Oracle 19c Client silent install
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

$OracleClientInstallParams = @{
    FilePath         = "$WorkingDirectory\OracleClient\client\setup.exe"
    WorkingDirectory = "$WorkingDirectory\OracleClient\client"
    ArgumentList     = "-silent -noconfig -nowait -responseFile $WorkingDirectory\OracleClient\client\client_install.rsp"
    Wait             = $true
    NoNewWindow      = $true
}

Start-Process @OracleClientInstallParams

# Copy tnsnames.ora file to correct location, may not be in the usual place, check both
if (Test-Path "$ConfigurationManagementRepo\powershell\Configs\$($Config.tnsorafile)") {
    Copy-Item -Path "$ConfigurationManagementRepo\powershell\Configs\$($Config.tnsorafile)" -Destination "$($Config.ORACLE_HOME)\network\admin\tnsnames.ora" -Force
    Write-Output "Copied tnsnames.ora file to $($Config.ORACLE_HOME)\network\admin\tnsnames.ora"
} elseif (Test-Path "C:\Users\Administrator\AppData\Local\Temp\modernisation-platform-configuration-management\powershell\Configs\$($Config.tnsorafile)") {
    Copy-Item -Path "C:\Users\Administrator\AppData\Local\Temp\modernisation-platform-configuration-management\powershell\Configs\$($Config.tnsorafile)" -Destination "$($Config.ORACLE_HOME)\network\admin\tnsnames.ora" -Force
    Write-Output "Copied tnsnames.ora file to $($Config.ORACLE_HOME)\network\admin\tnsnames.ora"
} else {
    Write-Error "Could not find tnsnames.ora file in $ConfigurationManagementRepo\powershell\Configs\$($Config.tnsorafile)"
    Write-Error "Could not find tnsnames.ora file in C:\Users\Administrator\AppData\Local\Temp\modernisation-platform-configuration-management\powershell\Configs\$($Config.tnsorafile)"
}

# Install Oracle configuration tools
$oracleConfigToolsParams = @{
    FilePath         = "$WorkingDirectory\OracleClient\client\setup.exe"
    WorkingDirectory = "$WorkingDirectory\OracleClient\client"
    ArgumentList     = "-executeConfigTools -silent -nowait -responseFile $WorkingDirectory\OracleClient\client\client_install.rsp"
    Wait             = $true
    NoNewWindow      = $true
}

Start-Process @oracleConfigToolsParams

[Environment]::SetEnvironmentVariable("ORACLE_HOME", $Config.ORACLE_HOME, [System.EnvironmentVariableTarget]::Machine)

# }}}

# {{{ Install BIP 4.2 client tools

# }}}

# {{{ Install BIP 4.3 client tools

# }}}

# {{{ login text
# Apply to all environments that aren't on the domain
# $ErrorActionPreference = "Stop"
# Write-Output "Add Legal Notice"

# if (-NOT (Test-Path $Config.RegistryPath)) {
#     Write-Output " - Registry path does not exist, creating"
#     New-Item -Path $Config.RegistryPath -Force | Out-Null
# }

# $RegistryPath = $Config.RegistryPath
# $LegalNoticeCaption = $Config.LegalNoticeCaption
# $LegalNoticeText = $Config.LegalNoticeText

# Write-Output " - Set Legal Notice Caption"
# New-ItemProperty -Path $RegistryPath -Name LegalNoticeCaption -Value $LegalNoticeCaption -PropertyType String -Force

# Write-Output " - Set Legal Notice Text"
# New-ItemProperty -Path $RegistryPath -Name LegalNoticeText -Value $LegalNoticeText -PropertyType String -Force
# }}}