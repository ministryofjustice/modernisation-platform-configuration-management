<#
.SYNOPSIS
    Supply a list of services to set as Auto (delayed start)
    To avoid them starting before other components or servers are running
.EXAMPLE
    Use the DISPLAYNAME property and wildcards to make discovery easier because some service names are instance specific i.e. SIANODENAME get's appended to certain BODS services

    . ../Common/Set-ServiceAutoDelayedStart.ps1 -Services "SAP Data Services" "Server Intelligence Agent*" "Apache Tomcat*"
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)][string[]]$Services
)

foreach ($Service in $Services) {

    $serviceName = (Get-Service | Where-Object { $_.DisplayName -like $Service }).Name

    if ($serviceName) {
        Write-Host "Setting $serviceName to Automatic (Delayed Start)..."
        # only possible to set using PowerShell 7.x so must use sc.exe here
        sc.exe config $serviceName start=delayed-auto        
    }
    else {
        Write-Host "ServiceName: $serviceName DOES NOT EXIST"
    }
}