# Script to test whether Group Policy UAC changes will actually allow installation of software that needs Admin/escalation

# We're not explicitly failing on this, it's just useful debug
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
Write-Output "Running as Administrator: $isAdmin"

# Complete UAC configuration for automation
$uacPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

function Test-UACSettings {
    param(
        [Parameter(Mandatory = $true)]
        [PSObject[]]$Settings,
        
        [Parameter(Mandatory = $true)]
        [string]$RegistryPath
    )
    
    foreach ($setting in $Settings) {
        $actualValue = (Get-ItemProperty -Path $RegistryPath -Name $setting.Name).$($setting.Name)
        
        if ($actualValue -eq $setting.ExpectedValue) {
            Write-Output "$($setting.Name) value correct: $actualValue"
        }
        else {
            Write-Output "$($setting.Name): $actualValue ERROR, should be $($setting.ExpectedValue)"
            Write-Output "Change GPO: $($setting.GPOSetting)"
            exit 1
        }
    }
}

# Define UAC settings to test
$uacSettings = @(
    [PSCustomObject]@{
        Name          = 'ConsentPromptBehaviorAdmin'
        ExpectedValue = 0
        GPOSetting    = 'User Account Control: Behavior of the elevation prompt for administrators in Admin Approval Mode -> Elevate without prompting'
    },
    [PSCustomObject]@{
        Name          = 'PromptOnSecureDesktop'
        ExpectedValue = 0
        GPOSetting    = 'User Account Control: Switch to the secure desktop when prompting for elevation -> Disabled'
    },
    [PSCustomObject]@{
        Name          = 'EnableLUA'
        ExpectedValue = 1
        GPOSetting    = 'User Account Control: Run all administrators in Admin Approval Mode -> Enabled'
    },
    [PSCustomObject]@{
        Name          = 'EnableInstallerDetection'
        ExpectedValue = 0
        GPOSetting    = 'User Account Control: Detect application installations and prompt for elevation -> Disabled'
    }
)

# Test all UAC settings
Test-UACSettings -Settings $uacSettings -RegistryPath $uacPath

