$DCName = "pcmcw0012"
$DomainName = "azure.hmpp.root"

# Critical ports for DC promotion
$DCPorts = @{
    53 = "DNS"
    88 = "Kerberos"
    135 = "RPC Endpoint Mapper"
    389 = "LDAP"
    636 = "LDAPS"
    3268 = "Global Catalog LDAP"
    3269 = "Global Catalog LDAPS (if using SSL/TLS)"
    445 = "SMB (for SYSVOL replication)"
    464 = "Kerberos Password Change"
    # 123 = "NTP (time synchronization)" # NTP won't respond to ICMP
    # 137 = "Netbios"
    # 138 = "Netbios"
    139 = "Netbios"
    # 5722 = "DFS"
    9389 = "WebServices"
}

Write-Host "Testing connectivity to $DCName for DC promotion..." -ForegroundColor Yellow
Write-Host "=" * 50

foreach ($Port in $DCPorts.Keys) {
    $Service = $DCPorts[$Port]
    $Result = Test-NetConnection -ComputerName $DCName -Port $Port -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    
    if ($Result.TcpTestSucceeded) {
        Write-Host "Port $Port ($Service): SUCCESS" -ForegroundColor Green
    } else {
        Write-Host "Port $Port ($Service): FAILED" -ForegroundColor Red
    }
}

# Test DNS resolution
Write-Host "`nTesting DNS resolution..." -ForegroundColor Yellow
try {
    $DNSTest = Resolve-DnsName -Name $DomainName -ErrorAction Stop
    Write-Host "DNS Resolution: SUCCESS" -ForegroundColor Green
} catch {
    Write-Host "DNS Resolution: FAILED" -ForegroundColor Red
}

# Test domain connectivity
Write-Host "`nTesting domain connectivity..." -ForegroundColor Yellow
try {
    $Domain = Get-ADDomain -Server $DCName -ErrorAction Stop
    Write-Host "Domain Connection: SUCCESS" -ForegroundColor Green
} catch {
    Write-Host "Domain Connection: FAILED" -ForegroundColor Red
}

# Query NTP server directly
w32tm /stripchart /computer:$DCName /samples:3

# Check time synchronization
w32tm /query /status
w32tm /query /peers