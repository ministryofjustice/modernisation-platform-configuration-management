<#
.SYNOPSIS
    Add all tools required to manage AD remotely

.DESCRIPTION
    Add Active Directory, DNS and group policy management tools

.EXAMPLE
    Install-ADRemoteTools.ps1
#>

$ErrorActionPreference = "Stop"
Install-WindowsFeature -Name RSAT-AD-PowerShell
Install-WindowsFeature -Name RSAT-ADDS -IncludeAllSubFeature
Install-WindowsFeature -Name RSAT-ADLDS
Install-WindowsFeature -Name RSAT-DNS-Server
Install-WindowsFeature -Name RSAT-File-Services -IncludeAllSubFeature
Install-WindowsFeature -Name GPMC
