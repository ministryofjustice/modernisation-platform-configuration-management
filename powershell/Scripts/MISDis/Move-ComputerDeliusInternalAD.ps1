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


function Move-ComputerDeliusInternalAD {

    $ErrorActionPreference = "Stop"

    $OUTarget = (Get-Tags)['server-type']
    $NewOU = "OU=$OUTarget,OU=Computers,OU=delius-mis-dev,DC=delius-mis-dev,DC=internal"

    Write-Host "Moving computer to OU: $NewOU"

    # Do nothing if host not part of domain
    if (-not (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
        return $false
    }

    # Create credential object for AD operations
    $password = Get-SecretString -SecretId 'delius-mis-dev-ad-admin-password'
    $secureString = ConvertTo-SecureString -AsPlainText -Force -String $password
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "Admin",$secureString

    # Get the computer's objectGUID with a 5-minute timeout
    $timeout = [DateTime]::Now.AddMinutes(5)
    do {
        try {
            
            $computer = Get-ADComputer -Credential $Credential -Filter "Name -eq '$($env:COMPUTERNAME)'" -ErrorAction Stop
            if ($computer -and $computer.objectGUID) { break }
        }
        catch {
            Write-Verbose "Get-ADComputer failed: $_"
        }
        Start-Sleep -Seconds 5
    } until (($computer -and $computer.objectGUID) -or ([DateTime]::Now -ge $timeout))

    if (-not ($computer -and $computer.objectGUID)) {
        Write-Error "Failed to retrieve computer objectGUID within 5 minutes."
        return
    }

    # Move the computer to the new OU
    $computer.objectGUID | Move-ADObject -TargetPath $NewOU -Credential $Credential
    Write-Host "Computer moved to new OU"

    # force group policy update
    gpupdate /force
}

function Get-SecretString {
    param (
        [Parameter(Mandatory)]
        [string]$SecretId
    )

    try {
        $secret = aws secretsmanager get-secret-value --secret-id $SecretId --query SecretString --output text

        if ($null -eq $secret -or $secret -eq '') {
            Write-Host "The SecretId '$SecretId' does not exist or returned no value."
            return $null
        }

        return $secret
    }
    catch {
        Write-Host "An error occurred while retrieving the secret: $_"
        return $null
    }
}

Move-ComputerDeliusInternalAD
