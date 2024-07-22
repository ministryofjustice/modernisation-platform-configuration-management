. ../ModPlatformAD/Join-ModPlatformAD.ps1

# TODO: configure this properly
# Deployment Example
# Set $RDGWFQDB and $RDSH accordingly
# Note RDGateway is also installed on server but isn't used so the deployment doesn't mess with the actual gateway.
#$RDGWFQDN = "rdgateway1.hmpps-domain-services.hmpps-preproduction.modernisation-platform.service.justice.gov.uk"
#$RDSH = @("my-session-host1.fqdn", "my-session-host2.fqdn")
#$RDLIC = "my-licensing-server.fqdn"
#$LOCALHOST = "$env:computername.$env:userdnsdomain" 
#Add-WindowsFeature -Name RDS-Connection-Broker -IncludeManagementTools
#Add-WindowsFeature -Name RDS-Web-Access -IncludeManagementTools
#New-RDSessionDeployment -ConnectionBroker $LOCALHOST -SessionHost $RDSH -WebAccessServer $LOCALHOST
#Add-RDServer -Server $RDLIC -Role RDS-Licensing -ConnectionBroker $LOCALHOST
#Set-RDLicenseConfiguration -Mode PerUser -LicenseServer $RDLIC -ConnectionBroker $LOCALHOST
#Add-RDServer -Server $LOCALHOST -Role RDS-Gateway -ConnectionBroker $LOCALHOST -GatewayExternalFqdn $RDGWFQDN

# Collection Example
#$CollectionName = "Test1"
#$CollectionDescription = "Test1"
#$CollectionSessionHost = @("my-session-host1.fqdn")
#$CollectionUserGroup = @("Azure\Domain Users")
#New-RDSessionCollection -CollectionName $CollectionName -SessionHost $CollectionSessionHost -ConnectionBroker $LOCALHOST -CollectionDescription $CollectionDescription
#Set-RDSessionCollectionConfiguration -CollectionName $CollectionName -ConnectionBroker $LOCALHOST -UserGroup $CollectionUserGroup

# Remote-App Example
#$RDAppAlias = "Calc2022"
#$RDAppDisplayName = "Calc2022"
#$RDAppFilePath = "C:\Windows\System32\win32calc.exe"
#New-RDRemoteApp -Alias $RDAppAlias -DisplayName $RDAppDisplayName -FilePath $RDAppFilePath -ShowInWebAccess 1 -CollectionName $CollectionName -ConnectionBroker $LOCALHOST

. ../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1
Exit $LASTEXITCODE
