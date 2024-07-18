<#
.DESCRIPTION
    Get the host OS version as Local Group policy settings may differ on a per-version basis.
#>
function Get-OSVersion {
    $osVersion = (Get-WmiObject -Class Win32_OperatingSystem).Caption

    if ($osVersion -like "*2012*") {
        return "2012" 
    } elseif ($osVersion -like "*2016*") {
        return "2016" 
    } elseif ($osVersion -like "*2019*") {
        return "2016" # 2019 is based on 2016
    } elseif ($osVersion -like "*2022*") {
        return "2022"
    } else {
        return "Unknown"
    }
}

<#
.SYNOPSIS
    Sets the registry values based on the configuration provided.
.DESCRIPTION
    Sets registry values from the Config<osVersion> hashtable.
    See links to each configuration for per-os settings.
.PARAMETER Config
    The configuration to set the registry values for.
    Config2012, Config2016, Config 2022
#>

function Set-RegistryValues {
    param (
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )

    foreach ($keyPath in $Config.Keys) {
        # Check if the key exists, if not create it
        if (!(Test-Path $keyPath)) {
            New-Item -Path $keyPath -Force | Out-Null
        }

        # Set each property for the current key
        foreach ($propertyName in $Config[$keyPath].Keys) {
            $propertyValue = $Config[$keyPath][$propertyName].Value
            $propertyType = $Config[$keyPath][$propertyName].Type

            Set-ItemProperty -Path $keyPath -Name $propertyName -Value $propertyValue -Type $propertyType -Force
        }
    }
}

<#
.SYNOPSIS
    Sets the local group policy based on the Windows version.
.PARAMETER WindowsVersion
    The version of Windows Server to set the local group policy for.
#>
function Set-LocalGroupPolicy {
    param(
        [Parameter(Mandatory=$true)]
        [string]$WindowsVersion
    )

    $configVariable = "Config$WindowsVersion"
    Write-Host $configVariable
    if (Get-Variable -Name $configVariable -ErrorAction SilentlyContinue) {
        $config = Get-Variable -Name $configVariable -ValueOnly
        Set-RegistryValues -Config $config
    } else {
        Write-Error "Configuration for Windows Server $WindowsVersion not found."
    }
}

# use registry settings from https://admx.help/?Category=Windows_8.1_2012R2
$Config2012 = @{
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" = @{
        "ElevateNonAdmins" = @{
            Value = 0 # Only Admins will see Updates Available messages
             Type = "DWORD"
         }
     }
    "HKLM:\SOFTWARE\Policies\Microsoft\WIndows\WindowsUpdate\AU" = @{
        "NoAutoRebootWithLoggedOnUsers" = @{
            Value = 1 # Restarts only happen if logged on user initiates
            Type = "DWORD"
        }
        "NoAutoUpdate" = @{
            Value = 3 # Download updates and notify for install
            Type = "DWORD"
        }
    }
}


# See https://admx.help/?Category=Windows_10_2016 for settings
# This config will also apply to Windows Server 2019
$Config2016 = @{
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" = @{
        "ExcludeWUDriversInQualityUpdate" = @{
            Value = 1 # Driver updates won't be downloaded
            Type = "DWORD"
        }
        "ElevateNonAdmins" = @{
            Value = 0 # Only Admins will see Updates Available messages
            Type = "DWORD"
        }
    }
    "HKLM:\SOFTWARE\Policies\Microsoft\WIndows\WindowsUpdate\AU" = @{
        "NoAutoRebootWithLoggedOnUsers" = @{
            Value = 1 # Restarts only happen if logged on user initiates
            Type = "DWORD"
        }
        "NoAutoUpdate" = @{
            Value = 3 # Download updates and notify for install
            Type = "DWORD"
        }
    }

}

# See https://admx.help/?Category=Windows_11_2022 for settings
$Config2022 = @{
    "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" = @{
        "ExcludeWUDriversInQualityUpdate" = @{
            Value = 1 # Driver updates won't be downloaded
            Type = "DWORD"
        }
        "ElevateNonAdmins" = @{
            Value = 0 # Only Admins will see Updates Available messages
            Type = "DWORD"
        }
    }
    "HKLM:\SOFTWARE\Policies\Microsoft\WIndows\WindowsUpdate\AU" = @{
        "NoAutoRebootWithLoggedOnUsers" = @{
            Value = 1 # Restarts only happen if logged on user initiates
            Type = "DWORD"
        }
        "NoAutoUpdate" = @{
            Value = 3 # Download updates and notify for install
            Type = "DWORD"
        }
    }
}

# Get the OS version
$osVersion = Get-OSVersion

# Sets the local group policy based on the OS version 
Set-LocalGroupPolicy -WindowsVersion $osVersion
