# Script to test whether Group Policy UAC changes will actually allow installation of software that needs Admin/escalation

function Get-Installer {
    param(
        [string]$Url,
        [string]$Destination
    )

    Invoke-WebRequest -Uri $Url -Destination $Destination

}

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')

Write-Output "Running as Administrator: $isAdmin"

# Complete UAC configuration for automation
$uacPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'

# Check disable prompting for administrators (critical)
$consentPromptBehaviorAdminValue = (Get-ItemProperty -Path $uacPath -Name 'ConsentPromptBehaviorAdmin').ConsentPromptBehaviorAdmin

Write-Output "ConsentPromptBehaviourAdmin: $consentPromptBehaviorAdminValue - should be 0"


# Check disable secure desktop (critical for automation)
$promptOnSecureDesktopValue = (Get-ItemProperty -Path $uacPath -Name 'PromptOnSecureDesktop').PromptOnSecureDesktop

Write-Output "PromptOnSecureDesktop: $PromptOnSecureDesktopValue - should be 0"

# Check UAC enabled (recommended)
$enableLUAValue = (Get-ItemProperty -Path $uacPath -Name 'EnableLUA').EnableLUA

Write-Output "EnableLUA value: $EnableLUAValue - should be 1"

# Verify settings
Get-ItemProperty -Path $uacPath | Select-Object ConsentPromptBehaviorAdmin, PromptOnSecureDesktop, EnableLUA

Get-Installer -Url 'https://code.visualstudio.com/sha/download?build=stable&os=win32-x64' -Destination "$env:Temp\vscode_installer.exe"

$unattendedArgs = '/VERYSILENT /NORESTART /MERGETASKS=!runcode'

Start-Process -FilePath $Destination -ArgumentList $unattendedArgs -Wait -PassThru