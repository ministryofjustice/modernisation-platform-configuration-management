<#
.SYNOPSIS
    Open a Windows Firewall Port

.EXAMPLE
    Set-WindowsFireWallPortOpenInbound '8080'
    Set-WindowsFireWallPortOpenInbound -Port '8080'
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)][string]$Port
)

if (Get-NetFirewallPortFilter -Protocol 'TCP' | Where-Object { $_.LocalPort -eq $Port }) {
    Write-Host "Firewall rule already exists for port: $Port"
}
else {
    New-NetFirewallRule -DisplayName "Allow Inbound traffic on port: $Port" -Direction Inbound -LocalPort $Port -Protocol 'TCP' -Action 'Allow'
}