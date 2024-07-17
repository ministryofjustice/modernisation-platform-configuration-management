<#
.SYNOPSIS
    This script will configure the local group policy settings for a non-domain joined machine.
.DESCRIPTION
    This script will configure the local group policy settings for a non-domain joined machine.
    The script will configure the following settings:
    - Windows Updates will be downloaded but not automatically installed
    - Non-Admin users will not be notified that windows updates are available
    - Updates will not be installable during automatic maintenance
    - Windows Updates won't include drivers
    - No auto-restart with logged on users for scheduled automatic updates  
.PARAMETER
    We might be able to add GPO settings here
.EXAMPLE
    .\Set-LocalGroupPolicy.ps1
#>
function Set-LocalGroupPolicy {
    # Set Windows Update settings
    $WindowsUpdateKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    $WindowsUpdateKeyExists = Test-Path $WindowsUpdateKey
    if (-not $WindowsUpdateKeyExists) {
        New-Item -Path $WindowsUpdateKey -Force
    }
    Set-ItemProperty -Path $WindowsUpdateKey -Name "AUOptions" -Value 3
}

# TODO: CHECK ALL THESE SETTINGS!!
