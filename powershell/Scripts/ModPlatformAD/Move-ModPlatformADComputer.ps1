function Move-ModPlatformADComputer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)][System.Management.Automation.PSCredential]$ModPlatformADCredential,
        [Parameter(Mandatory = $true)][string]$NewOU
    )

    $ErrorActionPreference = "Stop"

    # Check if host is part of domain, exit gracefully if not
    if (-not (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
        Write-Output "Computer is not yet joined to a domain. Will try again later."
        return $true # Return success to allow script to run again later
    }

    # Get the computer's objectGUID with a 15-minute timeout
    $timeout = [DateTime]::Now.AddMinutes(15)
    do {
        $computer = Get-ADComputer -Credential $ModPlatformADCredential -Identity $env:COMPUTERNAME -ErrorAction SilentlyContinue
        if ($computer -and $computer.objectGUID) { break }
        Write-Output "Waiting for computer objectGUID to be available..."
        Start-Sleep -Seconds 15
    } until (($computer -and $computer.objectGUID) -or ([DateTime]::Now -ge $timeout))

    if (-not ($computer -and $computer.objectGUID)) {
        Write-Error "Failed to retrieve computer objectGUID within 15 minutes."
        return $false
    }

    # Check if the computer is already in the correct OU
    if ($computer.DistinguishedName -like "*$NewOU") {
        Write-Output "Computer $env:COMPUTERNAME is already in the correct OU: $NewOU"
        return $true
    }

    # Move the computer to the new OU
    $computer.objectGUID | Move-ADObject -TargetPath $NewOU -Credential $ModPlatformADCredential

    # force group policy update
    gpupdate /force
}

function Get-Config {
    $tokenParams = @{
        TimeoutSec = 10
        Headers    = @{"X-aws-ec2-metadata-token-ttl-seconds" = 3600 }
        Method     = 'PUT'
        Uri        = 'http://169.254.169.254/latest/api/token'
    }
    $Token = Invoke-RestMethod @tokenParams

    $instanceIdParams = @{
        TimeoutSec = 10
        Headers    = @{"X-aws-ec2-metadata-token" = $Token }
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

$GlobalConfig = @{
    "all"                                 = @{
    }
    "hmpps-domain-services-development"   = @{
        "nartComputersOU" = "OU=RDS,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
        "NcrShortcuts"    = @{
        }
    }
    "hmpps-domain-services-test"          = @{
        "nartComputersOU" = "OU=RDS,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=NOMS,DC=ROOT"
        "NcrShortcuts"    = @{
        }
    }
    "hmpps-domain-services-preproduction" = @{
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT"
        "NcrShortcuts"    = @{
        }
    }
    "hmpps-domain-services-production"    = @{
        "nartComputersOU" = "OU=Nart,OU=MODERNISATION_PLATFORM_SERVERS,DC=AZURE,DC=HMPP,DC=ROOT"
        "NcrShortcuts"    = @{
        }
    }
}

$Config = Get-Config
Import-Module ModPlatformAD -Force
$ADConfig = Get-ModPlatformADConfig
$ADAdminCredential = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig
# Move the computer to the correct OU
Move-ModPlatformADComputer -ModPlatformADCredential $ADAdminCredential -NewOU $($Config.nartComputersOU)
