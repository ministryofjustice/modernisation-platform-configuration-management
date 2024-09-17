$GlobalConfig = @{
    "all"                                    = @{
        "WindowsClientS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
        "WindowsClientS3Folder" = "hmpps/onr"
        "OracleClientS3File"   = "WINDOWS.X64_193000_client.zip" # Oracle 19c client SW, install 1st
        "IPSS3File"             = "51054935.ZIP" # Information Platform Services 4.2 SP9 Patch 0
        "DataServicesS3File"    = "DS4214P_11-20011165.exe" # Data Services 4.2 SP14 Patch 11
        "RegistryPath"          = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon"
        "LegalNoticeCaption"    = "IMPORTANT"
        "LegalNoticeText"       = "This system is restricted to authorized users only. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information"
    }
    "oasys-national-reporting-development"   = @{
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
$AppDirectory = "E:\Apps"

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
# }}}

# {{{ prepare assets
$Config = Get-Config
New-Item -ItemType Directory -Path $WorkingDirectory -Force
New-Item -ItemType Directory -Path $AppDirectory -Force
New-Item -ItemType Directory -Path $AppDirectory/Client/client -Force

Set-Location -Path $WorkingDirectory
Get-Installer -Key $Config.OracleClientS3File -Destination (".\" + $Config.OracleClientS3File)
Get-Installer -Key $Config.IPSS3File -Destination (".\" + $Config.IPSS3File)
Get-Installer -Key $Config.DataServicesS3File -Destination (".\" + $Config.DataServicesS3File)

Expand-Archive ( ".\" + $Config.OracleClientS3File) -Destination ".\OracleClient"
Expand-Archive ( ".\" + $Config.IPSS3File) -Destination ".\IPS"
# }}}


# {{{ install Oracle
# Set-Location -Path $AppDirectory/Client/client
# documentation: https://docs.oracle.com/en/database/oracle/oracle-database/19/ntcli/running-oracle-universal-installe-using-the-response-file.html
# FIXME file name needs fixing
# .\setup.exe -silent -noconfig -nowait -responseFile ($ConfigurationManagementRepo + "\powershell\Configs\ONROracle19cResponse.rsp")
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
