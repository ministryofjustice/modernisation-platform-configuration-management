<#
.SYNOPSIS
    Adds a local SMB share if it doesn't already exist

.EXAMPLE
    Add-SmbShare.ps1 -Path C:\MyLocalPath MyShareName
#>

[CmdletBinding()]
param (
    [string]$Path,
    [string]$ShareName
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -Path $Path)) {
    New-Item -Path $Path -ItemType Directory -Force | Out-Null
    Write-Output "$ShareName - Created directory $Path"
}

$ExistingShare = Get-SmbShare -Name $ShareName -ErrorAction SilentlyContinue
if (-not $ExistingShare) {
    New-SmbShare -Name $ShareName -Path $Path -NoAccess "Everyone" | Out-Null
    Write-Output "$ShareName - Created SMB share to $Path"
} elseif ($ExistingShare.Path -ne $Path) {
    Write-Error "$ShareName - ERROR: share mapped to a different path"
} else {
    Write-Verbose "$ShareName - SMB share to $Path already exists"
}

$EveryoneAccess = Get-SmbShareAccess -Name $ShareName -ErrorAction SilentlyContinue |
    Where-Object { $_.AccountName -eq "Everyone" -and $_.AccessRight -eq "Full" -and $_.AccessControlType -eq "Allow" }

if (-not $EveryoneAccess) {
    Grant-SmbShareAccess -Name $ShareName -AccountName "Everyone" -AccessRight Full -Force | Out-Null
    Write-Output "$ShareName - Granted Everyone Full Control share permission as per Microsoft guidance"
} else {
    Write-Verbose "$ShareName - Everyone already has Full Control share permission as per Microsoft guidance"
}

$DisabledRules = Get-NetFirewallRule -DisplayGroup "File and Printer Sharing" -ErrorAction SilentlyContinue |
    Where-Object { $_.Enabled -eq "False" }

if ($DisabledRules) {
    Enable-NetFirewallRule -DisplayGroup "File and Printer Sharing"
    Write-Output "$ShareName - Enabled 'File and Printer Sharing' firewall rules"
} else {
    Write-Verbose "$ShareName - 'File and Printer Sharing' firewall rules already enabled"
}
