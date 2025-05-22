
# Import-Module ActiveDirectory

# Define the sites
$sites = @("azure-ukwest", "azure-uksouth", "mod-platform")

foreach ($site in $sites) {
    New-ADReplicationSite -Name $site
    Write-Host "Created site: $site"
 }


# Test the sites before trying to create the links
$n = 10
$i = 1
foreach ($site in $sites) {
    do {
        write-host "Test the $site site before trying to create the links"
        $siteExists = Get-ADReplicationSite -Filter {Name -eq $site}
    if (-not $siteExists) {
        Write-Host "Test unsuccessful, trying again in 2 seconds"
        start-sleep -Seconds 2
        $i ++        
    } else {
    Write-Host "Site exists: $site"
    }
    } until ($siteExists -or ($i -ge $n))
    If (!($siteExists)) {
        Write-Host "Sites have not settled yet"
        throw
    }
    }
    
    
# Create site links between each pair of sites
foreach ($i in 0..($sites.Length - 2)) {
  foreach ($j in ($i + 1)..($sites.Length - 1)) {
    $siteLinkName = "$($sites[$i])-$($sites[$j])"
    New-ADReplicationSiteLink -Name $siteLinkName -SitesIncluded $sites[$i], $sites[$j] -InterSiteTransportProtocol IP -Cost 100 -ReplicationFrequencyInMinutes 15
    # The default replication interval is 180 minutes, or 3 hours. The minimum interval is 15 minutes.
    Write-Host "Created site link: $siteLinkName"
  }
}

# New-ADReplicationSubnet
#    [-WhatIf] [-Confirm] [-AuthType <ADAuthType>] [-Credential <PSCredential>] [-Description <String>]
#    [-Instance <ADReplicationSubnet>] [-Location <String>] [-Name] <String> [-OtherAttributes <Hashtable>]
#    [-PassThru] [-Server <String>] [[-Site] <ADReplicationSite>] [<CommonParameters>]

# NOMS Dev test vnets
New-ADReplicationSubnet -Name "10.101.0.0/16" -Site "azure-ukwest" -Description "NOMS Dev & Test Environments-test" 
New-ADReplicationSubnet -Name "10.102.0.0/16" -Site "azure-ukwest" -Description "NOMS Dev & Test Environments-mgmt" # has DC MGMCW0002 = "10.102.0.196"

# mod-platform vpcs
New-ADReplicationSubnet -Name "10.20.0.0/16" -Description "mod-platform-core" -Site "mod-platform"
New-ADReplicationSubnet -Name "10.26.0.0/16" -Description "mod-platform-non-live" -Site "mod-platform"
New-ADReplicationSubnet -Name "10.27.0.0/16" -Description "mod-platform-live" -Site "mod-platform"

# NOMS Prod vnets
New-ADReplicationSubnet -Name "10.40.128.0/20" -Site "azure-ukwest" -Description "noms-mgmt-live"
New-ADReplicationSubnet -Name "10.40.160.0/20" -Site "azure-ukwest" -Description "noms-transit-live"
New-ADReplicationSubnet -Name "10.40.0.0/18" -Site "azure-ukwest" -Description "noms-live"

# NOMS Prod DR vnets (UKS)
New-ADReplicationSubnet -Name "10.40.144.0/20" -Site "azure-uksouth" -Description "noms-mgmt-live-dr"
New-ADReplicationSubnet -Name "10.40.176.0/20" -Site "azure-uksouth" -Description "noms-transit-live-dr"
New-ADReplicationSubnet -Name "10.40.64.0/18" -Site "azure-uksouth" -Description "noms-live-dr"


# Digital Prisons (UKS)
New-ADReplicationSubnet -Name "10.44.0.0/20" -Site "azure-uksouth" -Description "pfs-dev-net"
New-ADReplicationSubnet -Name "10.44.16.0/20" -Site "azure-uksouth" -Description "pfs-mgt-net"
New-ADReplicationSubnet -Name "10.43.160.0/20" -Site "azure-uksouth" -Description "pfs-prod-dp-mgmt-net"
New-ADReplicationSubnet -Name "10.43.208.0/20" -Site "azure-uksouth" -Description "pfs-prod-dp-net"



# Assign the DC's to their respective sites
Move-ADDirectoryServer -Identity "MGMCW0002" -Site "azure-ukwest"     # DC MGMCW0002     = "10.102.0.196"
Move-ADDirectoryServer -Identity "AD-AZURE-DC-A" -Site "mod-platform" # DC AD-AZURE-DC-A = "10.20.104.5"
Move-ADDirectoryServer -Identity "AD-AZURE-DC-B" -Site "mod-platform" # DC AD-AZURE-DC-B = "10.20.106.5"


# Set-ADReplicationSubnet -Identity $SubnetAddress -Site $SiteName # Assign a pre-created subnet to a site


# Verify the site assignment of the domain controller
# $DomainControllerName = "DC1"
# $DCInfo = Get-ADDomainController -Identity $DomainControllerName
# Write-Output "Domain Controller '$DomainControllerName' is assigned to site '$($DCInfo.SiteName)'."


# check replication
repadmin /showrepl *

#force replication 
repadmin /syncall /A /e

dcdiag /test:replications


