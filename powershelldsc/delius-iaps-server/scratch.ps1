if (! (Test-Path "C:\temp")) {
  mkdir C:\temp
}
cd C:\temp

# Invoke DSC
Start-DscConfiguration -Wait -Verbose  -path .\mofs -Force

# See previous DSC runs
Get-DscConfigurationStatus -All

# Download S3 objects - this is now part of the DSC
copy-S3Object -BucketName delius-iaps-development-artefacts -LocalFolder ./delius-iaps-development-artefacts/ -KeyPrefix "*"  

# Testing Oracle 12 install
Start-Process -FilePath 'C:\Program Files\7-Zip\7z.exe'-Wait -ArgumentList "x -oC:\setup\oracle\install $ArtefactsPath\OracleClient\Oracle_12c_Win32_12.1.0.2.0.7z"
Start-Process -FilePath "C:\temp\delius-iaps-development-artefacts\OracleClient\Oracle_12c_Win32_12.1.0.2.0\client32\setup.exe" -Verb RunAs -ArgumentList "-silent -nowelcome -nowait -noconfig 'ORACLE_HOSTNAME=$env:computername' -responseFile C:\temp\client.rsp" -Wait -verbose 

# Sample beginnings of DSC - with script forming part of a resource
	Script SetupOracleClient {
		GetScript = { return $false }
		TestScript = { return $false }
		SetScript = {
			try {
				Start-Process $env:ProgramFiles\7-Zip\7z.exe "x -oC:\setup\oracle\install $using:ArtefactsPath\OracleClient\Oracle_12c_Win32_12.1.0.2.0.7z" -Wait -Verb RunAs
			}
			catch [Exception] {
				Write-Host ('Failed to extract Oracle client setup using 7z')
				echo $_.Exception|format-list -force
				exit 1
			}

			try {
				$oaparamfile = 'C:\Setup\Oracle\Install\Oracle_12c_Win32_12.1.0.2.0\client32\install\oraparam.ini'
				if (Test-Path -Path $oaparamfile) {
					((Get-Content -path $oaparamfile -Raw) -replace 'MSVCREDIST_LOC=vcredist_x64.exe','MSVCREDIST_LOC=vcredist_x86.exe') | Set-Content -Path $oaparamfile 
				} else {
					write-host('Error - could not find oracle setup param file: $oaparamfile')
					exit 1
				}
				# Create x86 reg entry
				Push-Location
				Set-Location 'HKLM:'
				New-Item -Path '.\SOFTWARE\Wow6432Node' -Name ORACLE -Type Directory -Force
				New-Itemproperty -Path .\SOFTWARE\Wow6432Node\ORACLE -Name 'inst_loc' -Value 'C:\Program Files (x86)\Oracle\Inventory' -PropertyType 'String'
				Pop-Location
			}
			catch [Exception] {
				Write-Host ('Failed creating x86 registry entries')
				echo $_.Exception|format-list -force
				exit 1
			}

		}
	} 

# Join computer to domain
$secretName = "ChangeMe"
$domainJoinUserName = "Administrator"
$domainJoinPassword = ConvertTo-SecureString((Get-SECSecretValue -SecretId $secretName).SecretString) -AsPlainText -Force
$domainJoinCredential = New-Object System.Management.Automation.PSCredential($domainJoinUserName, $domainJoinPassword)
$token = invoke-restmethod -Headers @{"X-aws-ec2-metadata-token-ttl-seconds"=3600} -Method PUT -Uri http://169.254.169.254/latest/api/token
$instanceId = invoke-restmethod -Headers @{"X-aws-ec2-metadata-token" = $token} -Method GET -uri http://169.254.169.254/latest/meta-data/instance-id
add-computer -DomainName "delius-iaps-development.local" -Credential $domainJoinCredential -NewName $instanceId 

