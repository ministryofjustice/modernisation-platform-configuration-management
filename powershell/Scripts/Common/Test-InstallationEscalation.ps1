# Script to test whether Group Policy UAC changes will actually allow installation of software that needs Admin/escalation

function Get-Installer {
    param(
        [string]$Url,
        [string]$Destination
    )

    Invoke-WebRequest -Uri $Url -Destination $Destination

}

Get-Installer -Url 'https://code.visualstudio.com/sha/download?build=stable&os=win32-x64' -Destination "$env:Temp\vscode_installer.exe"

$unattendedArgs = '/VERYSILENT /NORESTART /MERGETASKS=!runcode'

Start-Process -FilePath $Destination -ArgumentList $unattendedArgs -Wait -PassThru