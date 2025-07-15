# Set the registry key to prefer IPv4 over IPv6
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters"
$propertyName = "DisabledComponents"
$desiredValue = 0x20

# Check if property exists and get current value
if (Test-Path $registryPath) {
    $property = Get-ItemProperty -Path $registryPath -Name $propertyName -ErrorAction SilentlyContinue
    
    if ($property -and $property.$propertyName -eq $desiredValue) {
        Write-Verbose "Registry already configured to prefer IPv4 over IPv6."
    } else {
        # Set the property to prefer IPv4 over IPv6
        Write-Output "Updating registry to prefer IPv4 over IPv6. A system restart is required for changes to take effect."
        Set-ItemProperty -Path $registryPath -Name $propertyName -Value $desiredValue -Type DWord
    }
} else {
    Write-Output "Cannot set IPv4 preference as Registry path does not exist: $registryPath"
}
