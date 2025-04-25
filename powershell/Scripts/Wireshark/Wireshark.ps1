
if (!(Test-Path "C:\Program Files (x86)\etl2pcapng")) {
  Write-Output "Creating C:\Program Files (x86)\etl2pcapng"
  New-Item -Path "C:\Program Files (x86)\etl2pcapng" -ItemType Directory -Force | Out-Null
}
if (!(Test-Path "C:\Program Files (x86)\etl2pcapng.exe")) {
  Write-Output "Adding etl2pcapng.exe"
  Read-S3Object -BucketName "mod-platform-image-artefact-bucket20230203091453221500000001" -Key "hmpps/pcap/etl2pcapng.exe" -File "C:\Program Files (x86)\etl2pcapng.exe" | Out-Null
}

choco install -y kb2999226 
choco install -y kb3035131
choco install -y kb3033929 
choco install -y vcredist140 
choco install -y wireshark
