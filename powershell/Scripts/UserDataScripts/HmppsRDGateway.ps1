. ../ModPlatformAD/Join-ModPlatformAD.ps1

Add-WindowsFeature -Name RDS-Gateway -IncludeManagementTools
$config = Get-CimInstance -ClassName Win32_TSGatewayServerSettings -Namespace root\cimv2\terminalservices
Invoke-CimMethod -MethodName EnableTransport -Arguments @{TransportType=[uint16]2;enable=$false} -InputObject $config
Invoke-CimMethod -MethodName SetSslBridging -Arguments @{SslBridging=[uint32]1} -InputObject $config

. ../AmazonCloudWatchAgent/Install-AmazonCloudWatchAgent.ps1

Exit $LASTEXITCODE
