$GlobalConfig = @{
    "all"                                    = @{
        "WindowsClientS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
        "WindowsClientS3Folder" = "hmpps/onr"
        "WindowsClientS3File"   = "WINDOWS.X64_193000_client.zip" # Oracle 19c client SW, install 1st
        "IPSS3File"             = "IPS.ZIP" # IPS SW, install 2nd
        "DataServicesS3File"    = "DATASERVICES.ZIP" # BODS SW, install 3rd
        "BIPWindowsClientFile"  = "BIPLATCLNT4303P_300-70005711.EXE" # Client tool 4.3 SP 3
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
$WorkingDirectory = "C:\Temp"

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

    $awsParams = @{
        ArgumentList = @(
            'ec2',
            'describe-tags',
            '--filters',
            "Name=resource-id,Values=$InstanceId"
        )
    }
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
        Key        = Join-Path $Config.WindowsClientS3Folder $Key
        File       = $Destination
        Verbose    = $true
    }

    Read-S3Object @s3Params
}
# }}}

# {{{ prepare assets
$Config = Get-Config
New-Item -ItemType Directory -Path $WorkingDirectory -Force

Set-Location -Path $WorkingDirectory
Get-Installer -Key $Config.WindowsClientS3File -Destination (".\" + $Config.WindowsClientS3File)
Get-Installer -Key $Config.IPSS3File -Destination (".\" + $Config.IPSS3File)
Get-Installer -Key $Config.DataServicesS3File -Destination (".\" + $Config.DataServicesS3File)
Get-Installer -Key $Config.BIPWindowsClientFile -Destination (".\" + $Config.BIPWindowsClientFile)

Expand-Installer -File ( ".\" + $Config.WindowsClientS3File) -Destination ".\Client"
Expand-Installer -File ( ".\" + $Config.IPSS3File) -Destination ".\IPS"
Expand-Installer -File ( ".\" + $Config.DataServicesS3File) -Destination ".\DataServices"
# }}}


# {{{ install Oracle
Set-Location -Path $WorkingDirectory/Client/client
# documentation: https://docs.oracle.com/en/database/oracle/oracle-database/19/ntcli/running-oracle-universal-installe-using-the-response-file.html
# FIXME file name needs fixing
.\setup.exe -silent -noconfig -nowait -responseFile ($ConfigurationManagementRepo + "\powershell\Configs\NCROracle19Response.rsp")
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
