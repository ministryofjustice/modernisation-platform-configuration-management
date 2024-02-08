function Rename-ModPlatformADComputer {

<#
.SYNOPSIS
    Rename host to either instance id, name tag, or the given hostname

.DESCRIPTION
    Rename host to the given newHostname unless it is equal to
      tag:Name      - rename to value of the Name tag
      instanceId    - rename to the instance Id
      keep-existing - don't rename
    Outputs a string containing new hostname if rename succeeds, in which case reboot required

.PARAMETER newHostname
    String

.PARAMETER ModPlatformADCredential
    HashTable as returned from Get-ModPlatformADConfig function. Required if joined to domain

.EXAMPLE
    Rename-ModPlatformADComputer "tag:Name"

.OUTPUTS
    String
#>

  [CmdletBinding()]
  param (
    [string]$NewHostname,
    [hashtable]$ModPlatformADCredential
  )

  $Token = Invoke-RestMethod -ConnectionTimeoutSeconds 2 -OperationTimeoutSeconds 2 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -ConnectionTimeoutSeconds 2 -OperationTimeoutSeconds 2 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json

  if ($NewHostname -eq $null) {
    $NewHostname = $env:COMPUTERNAME
  } elseif ($NewHostname -eq "keep-existing") {
    $NewHostname = $env:COMPUTERNAME
  } elseif ($NewHostname -eq "tag:Name") {
    $NewHostname = ($Tags.Tags | Where-Object  {$_.Key -eq "Name"}).Value
  } elseif ($NewHostname -eq "instanceId") {
    $NewHostname = $InstanceId
  }  
  if ($NewHostname -ne $env:COMPUTERNAME) {
    if ($ModPlatformADCredential -eq $null) {
      Rename-Computer -NewName $NewHostname -Force
    } else {
      Rename-Computer -NewName $NewHostname -DomainCredential $ModPlatformADCredential -Force
    }
    Write-Host "INFO: Renaming EC2 instance to $NewHostname and then rebooting"
    return $NewHostname
  } else {
    return $null
  }
}

function Add-ModPlatformADComputer {
<#
.SYNOPSIS
    Join existing host to domain

.DESCRIPTION
    Join the host to the domain defined by the ModPlatformADConfig parameter
    using the credentials provided in the ModPlatformADCredential parameter 
    Returns true if successful and a reboot required, false if already joined

.PARAMETER ModPlatformADConfig
    HashTable as returned from Get-ModPlatformADConfig function

.PARAMETER ModPlatformADCredential
    AD credential as returned from Get-ModPlatformADCredential function.

.EXAMPLE
    Add-ModPlatformADComputer $ModPlatformADConfig $ModPlatformADCredential

.OUTPUTS
    boolean
#>

  [CmdletBinding()]
  param (
    [hashtable]$ModPlatformADConfig,
    [hashtable]$ModPlatformADCredential
  )
  
  $ErrorActionPreference = "Stop"

  # Check if already domain joined
  if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
    $ExistingDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
    if ($ExistingDomain -eq $ModPlatformADConfig.DomainNameFQDN) {
      return $false
    } 
  }

  # Install powershell features if missing
  if (-not (Get-Module -ListAvailable -Name "ActiveDirectory")) {
    Write-Host "INFO: Installing RSAT-AD-PowerShell feature"
    Install-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature
  }

  # Join the domain
  Write-Host "INFO: Joining $env:COMPUTERNAME to ${ModPlatformADConfig.DomainNameFQDN} domain"
  Add-Computer -DomainName $ModPlatformADConfig.DomainNameFQDN -Credential $credentials -Verbose -Force
  return $true
}

function Remove-ModPlatformADComputer {
.SYNOPSIS
    Remove host from existing domain

.DESCRIPTION
    Join the host to the domain defined by the ModPlatformADConfig parameter
    using the credentials provided in the ModPlatformADCredential parameter 
    Returns true if successful and a reboot required, false if already joined

.PARAMETER ModPlatformADConfig
    HashTable as returned from Get-ModPlatformADConfig function

.PARAMETER ModPlatformADCredential
    AD credential as returned from Get-ModPlatformADCredential function.

.EXAMPLE
    Add-ModPlatformADComputer $ModPlatformADConfig $ModPlatformADCredential

.OUTPUTS
    boolean
#>

  $ErrorActionPreference = "Stop"

  # Do nothing if host not part of domain
  if (-not (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
    return $false

  # Install powershell features if missing
  if (-not (Get-Module -ListAvailable -Name "ActiveDirectory")) {
    Write-Host "INFO: Installing RSAT-AD-PowerShell feature"
    Install-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature
  }

  # Join the domain
  Write-Host "INFO: Removing $env:COMPUTERNAME from ${ModPlatformADConfig.DomainNameFQDN} domain"
  Remove-Computer -DomainName $ModPlatformADConfig.DomainNameFQDN -Credential $credentials -Verbose -Force
  return $true
}
