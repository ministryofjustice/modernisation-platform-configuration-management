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
        "sysDbName" = "T2BOSYS"
        "audDbName" = "T2BOAUD"
        "tnsorafile" = "tnsnames_T2_BODS.ora"
        "OnrShortcuts" = @{
        }
    }
    "oasys-national-reporting-test"          = @{
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
$ConfigurationManagementRepo = "C:\Users\Administrator\AppData\Local\Temp\modernisation-platform-configuration-management"
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
$Config = Get-Config
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
$ResponseFileContent = @"
oracle.install.responseFileVersion=/oracle/install/rspfmt_clientinstall_response_schema_v19.0.0
ORACLE_HOME=$($Config.ORACLE_HOME)
ORACLE_BASE=$($Config.ORACLE_BASE)
oracle.install.IsBuiltInAccount=true
oracle.install.client.installType=Administrator
"@

$ResponseFileContent | Out-File -FilePath "$WorkingDirectory\OracleClient\client\client_install.rsp" -Force -Encoding ascii

# Install Oracle Client silent install
$OracleClientInstallParams = @{
    FilePath         = "$WorkingDirectory\OracleClient\client\setup.exe"
    WorkingDirectory = "$WorkingDirectory\OracleClient\client"
    ArgumentList     = "-silent -noconfig -nowait -responseFile $WorkingDirectory\OracleClient\client\client_install.rsp"
    Wait             = $true
    NoNewWindow      = $true
}

Start-Process @OracleClientInstallParams

# Copy tnsnames.ora file to correct location
Copy-Item -Path "$ConfigurationManagementRepo\powershell\Configs\$($Config.tnsorafile)" -Destination "$($Config.ORACLE_HOME)\network\admin\tnsnames.ora" -Force

# Install Oracle configuration tools
$oracleConfigToolsParams = @{
    FilePath         = "$WorkingDirectory\OracleClient\client\setup.exe"
    WorkingDirectory = "$WorkingDirectory\OracleClient\client"
    ArgumentList     = "-executeConfigTools -silent -responseFile $WorkingDirectory\OracleClient\client\client_install.rsp"
    Wait             = $true
    NoNewWindow      = $true
}

Start-Process @oracleConfigToolsParams
# }}}

# {{{ install IPS
$Tags = Get-InstanceTags

# set Secret Names based on environment
$dbenv = ($Tags | Where-Object { $_.Key -eq "oasys-national-reporting-environment" }).Value
$bodsSecretName  = "/ec2/onr-bods/$dbenv/passwords"
$sysDbSecretName = "/oracle/database/$($Config.sysDbName)/passwords"
$audDbSecretName = "/oracle/database/$($Config.audDbName)/passwords"

$onr_system_owner = Get-SecretValue -SecretId $sysDbSecretName -SecretKey "onr_system_owner"
$onr_audit_owner = Get-SecretValue -SecretId $audDbSecretName -SecretKey "onr_audit_owner"
$bods_cluster_key = Get-SecretValue -SecretId $bodsSecretName -SecretKey "bods_cluster_key"
#
# }}}

# {{{ install Data Services
#
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
