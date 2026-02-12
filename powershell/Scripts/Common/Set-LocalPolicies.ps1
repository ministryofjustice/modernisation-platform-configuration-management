function Get-ModPlatformPolicyConfig {
<#
.SYNOPSIS
    Retrieve appropriate Policy config for the given Server Type.

.OUTPUTS
    HashTable
#>

  $ModPlatformPolicyConfigs = @{
    'DeliusMisDis' = @(
      @{
        # User Account Control: Behavior of the elevation prompt for administrators in Admin Approval Mode -> Elevate without prompting
        Path  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        Name  = 'ConsentPromptBehaviorAdmin'
        Value = 0
      },
      @{
        # User Account Control: Switch to the secure desktop when prompting for elevation -> Disabled
        Path  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        Name  = 'PromptOnSecureDesktop'
        Value = 0
      },
      @{
        # User Account Control: Run all administrators in Admin Approval Mode -> Enabled
        Path  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        Name  = 'EnableLUA'
        Value = 1
      },
      @{
        # User Account Control: Detect application installations and prompt for elevation -> Disabled
        Path  = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
        Name  = 'EnableInstallerDetection'
        Value = 0
      }
    )
  }

  $Token = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
  $InstanceId = Invoke-RestMethod -TimeoutSec 10 -Headers @{"X-aws-ec2-metadata-token" = $Token} -Method GET -Uri http://169.254.169.254/latest/meta-data/instance-id
  $TagsRaw = aws ec2 describe-tags --filters "Name=resource-id,Values=$InstanceId"
  $Tags = "$TagsRaw" | ConvertFrom-Json
  $ServerTypeTag = ($Tags.Tags | Where-Object  {$_.Key -eq "server-type"}).Value
  if ($ServerTypeTag) {
    if ($ModPlatformPolicyConfigs.ContainsKey($ServerTypeTag)) {
      return $ModPlatformPolicyConfigs[$ServerTypeTag]
    } else {
      Write-Error "No matching policy configuration for ServerType ${ServerTypeTag}"
    }
  } else {
    Write-Error "Cannot find policy configuration, ensure ServerType tag defined"
  }
}

function Set-ModPlatformPolicyConfig {
<#
.SYNOPSIS
    Set local policy as per config
#>

  [CmdletBinding()]
  param (
    [Parameter(Mandatory=$true)]$ModPlatformPolicyConfig
  )


  foreach ($PolicyConfig in $ModPlatformPolicyConfig) {
    $ActualValue = (Get-ItemProperty -Path $PolicyConfig.Path -Name $PolicyConfig.Name).$($PolicyConfig.Name)
    if ($ActualValue -ne $PolicyConfig.Value) {
      Write-Output ($PolicyConfig.Path + ": " + $PolicyConfig.Name + ": Updating value " + $ActualValue + " -> " + $PolicyConfig.Value)
      Set-ItemProperty -Path $PolicyConfig.Path -Name $PolicyConfig.Name -Value $PolicyConfig.Value
    } else {
      Write-Debug ($PolicyConfig.Path + ": " + $PolicyConfig.Name + ": value already set to " + $ActualValue)
    }
  }
}

$ModPlatformPolicyConfig = Get-ModPlatformPolicyConfig
Set-ModPlatformPolicyConfig $ModPlatformPolicyConfig
