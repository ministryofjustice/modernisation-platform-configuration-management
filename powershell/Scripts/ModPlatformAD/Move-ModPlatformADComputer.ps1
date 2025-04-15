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

    # Check if the new OU exists
    $ouExists = Get-ADOrganizationalUnit -Credential $ModPlatformADCredential -Identity $NewOU -ErrorAction SilentlyContinue
    if (-not $ouExists) {
        Write-Error "Target OU does not exist: $NewOU"
        return $false
    } else {
        Write-Output "Target OU exists: $NewOU"
    }

    # Move the computer to the new OU
    $computer.objectGUID | Move-ADObject -TargetPath $NewOU -Credential $ModPlatformADCredential

    # force group policy update
    gpupdate /force
}

# NOTE: Only getting the tags here, not the config
function Get-Tags {
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
    
    # Create a hashtable of instance tags for easier access
    $tagHash = @{}
    foreach($tag in $Tags.Tags) {
        $tagHash[$tag.Key] = $tag.Value
    }
    
    return $tagHash
}

$Config = Get-Tags

# Get the OU to move the instance to without having a hardcoded value

# Get the domain name from the instance itself
$domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
if ($domain) {
    $domainDC = "," + (($domain.Split(".") | ForEach-Object { "DC=$_"}) -join ',')
} else {
    Write-Error "Domain not found"
    return $false
}
# Use the server-type tag as the OU name
$newOU = "OU=$($Config.'server-type'),OU=MODERNISATION_PLATFORM_SERVERS" + $domainDC

Import-Module ModPlatformAD -Force
$ADConfig = Get-ModPlatformADConfig
$ADAdminCredential = Get-ModPlatformADAdminCredential -ModPlatformADConfig $ADConfig
# Move the computer to the correct OU
Move-ModPlatformADComputer -ModPlatformADCredential $ADAdminCredential -NewOU $($Config.nartComputersOU)
