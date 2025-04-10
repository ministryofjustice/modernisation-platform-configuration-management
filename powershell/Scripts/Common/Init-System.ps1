function Add-PermanentPSModulePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$NewPath
    )
  
    # Get current Machine PSModulePath from the registry
    $regKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
    $currentValue = (Get-ItemProperty -Path $regKey -Name PSModulePath).PSModulePath
  
    # Check if the path already exists
    if ($currentValue -split ';' -notcontains $NewPath) {
        # Add the new path
        $newValue = $currentValue + ";" + $NewPath
  
        # Update the registry
        Set-ItemProperty -Path $regKey -Name PSModulePath -Value $newValue
  
        Write-Host "Added $NewPath to system PSModulePath. Changes will take effect after restart or refreshing environment variables."
    }
    else {
        Write-Host "$NewPath is already in PSModulePath"
    }
}

# Set the registry key to prefer IPv4 over IPv6
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" -Name "DisabledComponents" -Value 0x20 -Type DWord

# Output a message to confirm the change
Write-Host "Registry updated to prefer IPv4 over IPv6. A system restart is required for changes to take effect."

# Turn off the firewall as this will possibly interfere with Sia Node creation
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False

# Set local time zone to UK although this should now be set by Group Policy objects
Set-TimeZone -Name "GMT Standard Time"

# Add modules permanently to PSModulePath
$ModulesPath = Join-Path $PSScriptRoot "..\..\Modules"
Add-PermanentPSModulePath -NewPath $ModulesPath
# Add to system environment (persistent)
[Environment]::SetEnvironmentVariable("PSModulePath", $env:PSModulePath + ";" + $ModulesPath, "Machine")
# Also add to current session
$env:PSModulePath = $env:PSModulePath + ";" + $ModulesPath
