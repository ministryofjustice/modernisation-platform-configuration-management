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
        "RegistryPath"          = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon"
        "LegalNoticeCaption"    = "IMPORTANT"
        "LegalNoticeText"       = "This system is restricted to authorized users only. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information"
    }
    "oasys-national-reporting-development"   = @{
        "OnrShortcuts" = @{
        }
    }
    "oasys-national-reporting-test"          = @{
        "sysDbName" = "T2BOSYS"
        "audDbName" = "T2BOAUD"
        "tnsorafile" = "tnsnames_T2_BODS.ora"
        "cmsMainNode"     = "t2-onr-bods-1-b"
        "cmsExtendedNode" = "t2-onr-bods-2-a"
        "serviceUser"     = "svc_t2_onr_bods"
        "serviceUserPath" = "OU=Service,OU=Users,OU=NOMS RBAC,DC=AZURE,DC=NOMS,DC=ROOT"
        "serviceUserDescription" = "Onr BODS T2 service user for AWS"
        "domain"    = "AZURE"
        "group"     = "onr-t2-rdp"
        "groupPath" = "OU=Groups,OU=NOMS RBAC,DC=AZURE,DC=NOMS,DC=ROOT"
        "groupDescription" = "Onr BODS T2 RDP allow group"
        "OnrShortcuts" = @{
        }
    }
    "oasys-national-reporting-preproduction" = @{
        "OnrShortcuts" = @{
        }
    }
    "oasys-national-reporting-production"    = @{
        "OnrShortcuts" = @{
        }
    }
}

$tempPath = ([System.IO.Path]::GetTempPath())

$ConfigurationManagementRepo = "$tempPath\modernisation-platform-configuration-management"
$ErrorActionPreference = "Stop"
$WorkingDirectory = "D:\Software"
$AppDirectory = "E:\App"

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
    $secretJson = aws secretsmanager get-secret-value --secret-id $SecretId --query SecretString --output text
    $secretObject = $secretJson | ConvertFrom-Json
    return $secretObject.$SecretKey
}

function Get-InstanceTags {
  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = $TagsRaw | ConvertFrom-Json
  $Tags.Tags
}

# }}}

# {{{ prepare assets
# Set local time zone to UK
Set-TimeZone -Name "GMT Standard Time"

$Config = Get-Config
$Tags = Get-InstanceTags

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

# re-importing this if the machine has been rebooted, probably not needed
Import-Module ModPlatformAD -Force
$ADConfig = Get-ModPlatformADConfig
$ADCredential = Get-ModPlatformADJoinCredential -ModPlatformADConfig $ADConfig
$ComputerName = $env:COMPUTERNAME

New-ModPlatformADGroup -Group $($Config.group) -Path $($Config.groupPath) -Description $($Config.groupDescription) -ModPlatformADCredential $ADCredential
Add-ModPlatformGroupMember -Computer $ComputerName -Group $($Config.group) -ModPlatformADCredential $ADCredential

$dbenv = ($Tags | Where-Object { $_.Key -eq "oasys-national-reporting-environment" }).Value
$bodsSecretName  = "/ec2/onr-bods/$dbenv/passwords"

$serviceUserPlainTextPassword = Get-SecretValue -SecretId $bodsSecretName -SecretKey $($Config.serviceUser)
$serviceUserPassword = ConvertTo-SecureString -String $serviceUserPlainTextPassword -AsPlainText -Force

New-ModPlatformADUser -Name $($Config.serviceUser) -Path $($Config.serviceUserPath) -Description $($Config.serviceUserDescription) -accountPassword $serviceUserPassword -ModPlatformADCredential $ADCredential
Add-ModPlatformGroupUser -Group $($Config.group) -User $($Config.serviceUser) -ModPlatformADCredential $ADCredential

# Set the service user Remote Desktop Access permissions on the instance
# Invoke-Command -ComputerName $ComputerName -Credential $ADCredential -ScriptBlock {
#   param($serviceUser)
#   #Add the service user to the Remote Desktop Users group locally, if this isn't enough change to -Group Administrators
#   Add-LocalGroupMember -Group "Remote Desktop Users" -Member $serviceUser
# } -ArgumentList $($Config.serviceUser)
