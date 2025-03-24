$ErrorActionPreference = "Stop"
Install-WindowsFeature -Name RSAT-AD-PowerShell
Install-WindowsFeature -Name RSAT-ADDS -IncludeAllSubFeature
Install-WindowsFeature -Name RSAT-ADLDS
Install-WindowsFeature -Name RSAT-DNS-Server
Install-WindowsFeature -Name RSAT-File-Services -IncludeAllSubFeature
Install-WindowsFeature -Name GPMC
