$GlobalConfig = @{
    "all"                                    = @{
        "WindowsClientS3Bucket" = "mod-platform-image-artefact-bucket20230203091453221500000001"
        "WindowsClientS3Folder" = "hmpps/ncr-packages"
        "WindowsClientS3File"   = "WINDOWS.X64_193000_client.zip" # Oracle 19c client SW, install 1st
        "IPSS3File"             = "IPS.ZIP" # IPS SW, install 2nd
        "DataServicesS3File"    = "DATASERVICES.ZIP" # BODS SW, install 3rd
        "BIPWindowsClientFile"  = "BIPLATCLIENT4304P_500-70005711.EXE"
    }
    "nomis-combined-reporting-development"   = @{
        "NcrShortcuts" = @{
        }
    }
    "nomis-combined-reporting-test"          = @{
        "NcrShortcuts" = @{
        }
    }
    "nomis-combined-reporting-preproduction" = @{
        "NcrShortcuts" = @{
        }
    }
    "nomis-combined-reporting-production"    = @{
        "NcrShortcuts" = @{
        }
    }
}
$ConfigurationManagementRepo = "C:\Users\Administrator\AppData\Local\Temp\modernisation-platform-configuration-management"
$ErrorActionPreference = "Stop"
$WorkingDirectory = "C:\Temp"

# {{{ functions
function Get-Config {
    $Token = Invoke-RestMethod `
        -TimeoutSec 10 `
        -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = 3600 } `
        -Method PUT `
        -Uri http://169.254.169.254/latest/api/token
    $InstanceId = Invoke-RestMethod `
        -TimeoutSec 10 `
        -Headers @{"X-aws-ec2-metadata-token" = $Token } `
        -Method GET `
        -Uri http://169.254.169.254/latest/meta-data/instance-id
    $TagsRaw = aws ec2 describe-tags `
        --filters "Name=resource-id,Values=$InstanceId"
    $Tags = "$TagsRaw" | ConvertFrom-Json
    $EnvironmentNameTag = ($Tags.Tags | Where-Object { $_.Key -eq "environment-name" }).Value

    if (-not $GlobalConfig.Contains($EnvironmentNameTag)) {
        Write-Error "Unexpected environment-name tag value $EnvironmentNameTag"
    }
    Return $GlobalConfig.all + $GlobalConfig[$EnvironmentNameTag]
}

function Get-Installer {
    param (
        $Key
        $Destination
    )
    Read-S3Object `
        -BucketName $Config.WindowsClientS3Bucket `
        -Key ($Config.WindowsClientS3Folder + "/" + $Key) `
        -File (".\" + $Destination) `
        -Verbose
}

function Expand-Installer {
    param (
        $File
        $Destination
    )
    Expand-Archive `
        -Path (".\" + $File) `
        -DestinationPath ($WorkingDirectory + $Destination)
}
# }}}

$Config = Get-Config
New-Item -ItemType Directory -Path $WorkingDirectory -Force

# TODO: need to install these as well, just getting the files for now
Set-Location -Path $WorkingDirectory
Get-Installer -Key $Config.WindowsClientS3File -Destination $Config.WindowsClientS3File
Get-Installer -Key $Config.IPSS3File -Destination $Config.IPSS3File
Get-Installer -Key $Config.DataServicesS3File -Destination $Config.DataServicesS3File
Get-Installer -Key $Config.BIPWindowsClientFile -Destination $Config.BIPWindowsClientFile

Expand-Installer -File $Config.WindowsClientS3File -Destination "\Client"
Expand-Installer -File $Config.IPSS3File -Destination "\IPS"
Expand-Installer -File $Config.DataServicesS3File -Destination "\DataServices"
Expand-Installer -File $Config.BIPWindowsClientFile -Destination "\BIP"

# {{{ install Oracle
Set-Location -Path $WorkingDirectory/Client
# documentation: https://docs.oracle.com/en/database/oracle/oracle-database/19/ntcli/running-oracle-universal-installe-using-the-response-file.html
# FIXME file name needs fixing
setup.exe -silent -noconfig -nowait -responseFile ($ConfigurationManagementRepo + "\powershell\Configs\NCROracle19Response.ini")
# }}}
