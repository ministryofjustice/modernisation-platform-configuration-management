function Rename-ModPlatformADComputer {

<#
.SYNOPSIS
    Rename host to either instance id, name tag, or the given hostname

.DESCRIPTION
    Rename host to the given newHostname unless it is equal to
      tag:Name      - rename to value of the computer-name or Name tag
      instanceId    - rename to the instance Id. Doesn't work with netbios as length exceeds 15 chars.
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
    [System.Management.Automation.PSCredential]$ModPlatformADCredential
  )

  $ErrorActionPreference = "Stop"

  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json

  if (-not $NewHostname) {
    $NewHostname = $env:COMPUTERNAME
  } elseif ($NewHostname -eq "keep-existing") {
    $NewHostname = $env:COMPUTERNAME
  } elseif ($NewHostname -eq "tag:Name") {
    $NewHostname = ($Tags.Tags | Where-Object  {$_.Key -eq "computer-name"}).Value
    if (-not $NewHostname) {
      $NewHostname = ($Tags.Tags | Where-Object  {$_.Key -eq "Name"}).Value
    }
  } elseif ($NewHostname -eq "instanceId") {
    $NewHostname = $InstanceId
  }
  if ($NewHostname -ne $env:COMPUTERNAME) {
    if (-not $ModPlatformADCredential) {
      Rename-Computer -NewName $NewHostname -Force
    } else {
      Rename-Computer -NewName $NewHostname -DomainCredential $ModPlatformADCredential -Force
    }
    Write-Output "Renaming EC2 instance to $NewHostname and then rebooting"
    Return $NewHostname
  } else {
    Write-Verbose "EC2 instance already named correctly"
    Return $null
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
    AD credential as returned from Get-ModPlatformADJoinCredential function.

.EXAMPLE
    Add-ModPlatformADComputer $ModPlatformADConfig $ModPlatformADCredential

.OUTPUTS
    boolean
#>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][hashtable]$ModPlatformADConfig,
    [Parameter(Mandatory=$true)][System.Management.Automation.PSCredential]$ModPlatformADCredential
  )

  $ErrorActionPreference = "Stop"

  $DomainNameFQDN = $ModPlatformADConfig.DomainNameFQDN

  # Check if already domain joined
  if ((Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
    $ExistingDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
    if ($ExistingDomain -eq $DomainNameFQDN) {
      Write-Verbose "Computer $env:COMPUTERNAME is already joined to domain ${DomainNameFQDN}"
      Return $false
    }
  }

  # Install powershell features if missing
  if (-not (Get-Module -ListAvailable -Name "ActiveDirectory")) {
    Write-Output "Installing RSAT-AD-PowerShell feature"
    Install-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature
  }

  # Join the domain
  Write-Output "Joining $env:COMPUTERNAME to ${DomainNameFQDN} domain"
  Add-Computer -DomainName $DomainNameFQDN -Credential $ModPlatformADCredential -Verbose -Force
  Return $true
}

function Remove-ModPlatformADComputer {
<#
.SYNOPSIS
    Remove host from existing domain

.DESCRIPTION
    Remove the host from the current domain using the credentials provided
    in the ModPlatformADCredential parameter.
    Returns true if successful and a reboot required, false if already removed.

.PARAMETER ModPlatformADCredential
    AD credential as returned from Get-ModPlatformADJoinCredential function.

.EXAMPLE
    Add-ModPlatformADComputer $ModPlatformADConfig $ModPlatformADCredential

.OUTPUTS
    boolean
#>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)][System.Management.Automation.PSCredential]$ModPlatformADCredential
  )

  $ErrorActionPreference = "Stop"

  # Do nothing if host not part of domain
  if (-not (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain) {
    Write-Verbose "Computer $env:COMPUTERNAME is already removed from domain"
    Return $false
  }

  # Install powershell features if missing
  if (-not (Get-Module -ListAvailable -Name "ActiveDirectory")) {
    Write-Output "Installing RSAT-AD-PowerShell feature"
    Install-WindowsFeature -Name "RSAT-AD-PowerShell" -IncludeAllSubFeature
  }

  # Join the domain
  $DomainNameFQDN = (Get-WmiObject -Class Win32_ComputerSystem).Domain
  Write-Output "Removing $env:COMPUTERNAME from ${DomainNameFQDN} domain"
  Remove-Computer -Credential $ModPlatformADCredential -Verbose -Force
  Return $true
}

Export-ModuleMember -Function Rename-ModPlatformADComputer
Export-ModuleMember -Function Add-ModPlatformADComputer
Export-ModuleMember -Function Remove-ModPlatformADComputer
