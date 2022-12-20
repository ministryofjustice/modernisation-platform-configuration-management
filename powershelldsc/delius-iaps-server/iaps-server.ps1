$ConfirmPreference="none"
# $ErrorActionPreference="Stop"
# $VerbosePreference="Continue"
# Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
# Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
# Install-Module -Name ComputerManagementDsc -RequiredVersion 8.5.0
# Install-Module -Name cChoco -RequiredVersion 2.5.0.0
# Install-Module -Name NetworkingDsc -RequiredVersion 9.0.0

Configuration IAPS {
	param (
        [String]
        $ArtefactBucketName
    ) 

	Import-DscResource -ModuleName PsDesiredStateConfiguration
	Import-DscResource -ModuleName ComputerManagementDsc
	Import-DscResource -ModuleName cChoco
	Import-DscResource -ModuleName NetworkingDsc
  
	Node 'localhost' {

		$setupPath = "C:\setup"
        $artefactPath = Join-Path -Path $setupPath -ChildPath artefacts/

        SystemLocale SetWinSystemLocale {
            IsSingleInstance = "Yes"
            SystemLocale = "en-GB"
        }
        Script SetWinHomeLocation {
            SetScript = { Set-WinHomeLocation -GeoId 242 }
            TestScript = { 
                $currentGeoId = (Get-WinHomeLocation | % {$_.GeoId})
                return $currentGeoId -eq 242
            }
            GetScript = { @{ Result = (Get-WinHomeLocation | % {$_.HomeLocation}) } }
        }
        Script SetWinUserLanguageList {
            SetScript = { Set-WinUserLanguageList -LanguageList (New-WinUserLanguageList -Language en-GB) -Force }
            TestScript = { 
                $currentLanguageTag = Get-WinUserLanguageList | % {$_.LanguageTag}
                return $currentLanguageTag -eq "en-GB"
            }
            GetScript = { @{ Result = (Get-WinUserLanguageList | % {$_.LanguageTag}) } }
        }

         ### START - resources below are potentially not required
    #     File DefaultUser {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\files\windows\iaps\registry\default_user.reg"
    #         DestinationPath = "C:\Setup\Registry\default_user.reg"
    #         Ensure = "Present"
    #     }
    #     File LocalServiceUser {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\files\windows\iaps\registry\LocalService_user_S-1-5-19.reg"
    #         DestinationPath = "C:\Setup\Registry\LocalService_user_S-1-5-19.reg"
    #         Ensure = "Present"
    #     }
    #     File NetworkServiceUser {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\files\windows\iaps\registry\NetworkService_user_S-1-5-20.reg"
    #         DestinationPath = "C:\Setup\Registry\NetworkService_user_S-1-5-20.reg"
    #         Ensure = "Present"
    #     }
    #     Script ImportUserRegistryFiles {
    #         GetScript = { return $false }
    #         TestScript = { return $false }
    #         SetScript = { powershell.exe G:\hmpps-delius-iaps-packer\scripts\windows\iaps\ImportRegistryFiles.ps1 }
    #     }
    ### END

        cChocoInstaller InstallChoco {
            InstallDir = "C:\ProgramData\chocolatey"
        }
        cChocoPackageInstaller installNginx {
            Name = "nginx"
            Version = "1.23.2"
            # Params = "/installLocation:C:\nginx /port:80"
            DependsOn   = "[cChocoInstaller]installChoco"
        }
        cChocoPackageInstaller installFirefox {
            Name = "firefox"
            AutoUpgrade = $true
            DependsOn   = "[cChocoInstaller]installChoco"
        }
        cChocoPackageInstaller install7Zip {
            Name = "7zip"
            AutoUpgrade = $true
            DependsOn   = "[cChocoInstaller]installChoco"
        }
        cChocoPackageInstaller installOpenSsl {
            Name = "openssl.light"
            AutoUpgrade = $true
            DependsOn   = "[cChocoInstaller]installChoco"
        }
        cChocoPackageInstaller installSoapUi {
            Name = "soapui"
            AutoUpgrade = $true
            DependsOn   = "[cChocoInstaller]installChoco"
        }

        Script DisableWindowsFirewall {
            SetScript = { Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False }
            TestScript = { 
                $currentPrivateStatus = $(Get-NetFirewallProfile -Profile Private).Enabled
                $currentPublicStatus = $(Get-NetFirewallProfile -Profile Public).Enabled
                $currentDomainStatus = $(Get-NetFirewallProfile -Profile Domain).Enabled
                return ( ! ($currentPrivateStatus -or $currentPublicStatus -or $currentDomainStatus) )
            }
            GetScript = { @{ Result = $(get-netfirewallprofile -profile domain, private, public | foreach { "$($_.Name): $($_.Enabled)" }) -join "," } }
        }

        Script DownloadArtefacts {
            SetScript = {
                Copy-S3Object -BucketName $ArtefactBucketName -LocalFolder $using:artefactPath -KeyPrefix "*"   
            }
            TestScript = { 
                return (Test-Path -Path $using:artefactPath)
            }
            GetScript = { @{ Result = ("$artefactPath exists: $(Test-Path -Path $using:artefactPath)") } }
        }

		# Install Oracle 12c
		File OracleInstallerPath {
			Type = 'Directory'
			DestinationPath = join-path -path $setupPath -childPath "oracle/install"
			Ensure = "Present"
		} 

		# GOT HERE. This is not yet working, working on the manually invoking the script first.
		Script SetupOracleClient {
            GetScript = { return $false }
            TestScript = { return $false }
            SetScript = { powershell.exe G:\hmpps-delius-iaps-packer\scripts\windows\iaps\SetupOracleClient.ps1 }
        }

		# File OracleClientConfig {
        #     SourcePath = "G:\hmpps-delius-iaps-packer\files\windows\iaps\OracleClient.rsp"
        #     DestinationPath = "C:\Setup\Oracle\OracleClient.rsp"
        #     Ensure = "Present"
        # }
        # File OracleTsnNames {
        #     SourcePath = "G:\hmpps-delius-iaps-packer\files\windows\iaps\tnsnames.ora.tmpl"
        #     DestinationPath = "C:\Setup\Oracle\tnsnames.ora.tmpl"
        #     Ensure = "Present"
        # }
        # File OracleNet {
        #     SourcePath = "G:\hmpps-delius-iaps-packer\files\windows\iaps\sqlnet.ora.tmpl"
        #     DestinationPath = "C:\Setup\Oracle\sqlnet.ora.tmpl"
        #     Ensure = "Present"

        # Package OracleClient12c {
        #     Name = "Oracle Client 12c"
        #     ProductId = "EC9DE42E-67E1-4E9A-8684-76210B019545" # randomly generated unique ID
        #     Path = "C:\IAPS\S3\OracleClient\Oracle_12c_Win32_12.1.0.2.0\client32\setup.exe"
        #     Ensure = "Present"
        #     Arguments = "-silent -nowelcome -nowait -noconfig 'ORACLE_HOSTNAME=$env:COMPUTERNAME' -responseFile C:\IAPS\repo\Oracle Client\OracleClient.rsp"
        # }
    ## TODO END
        # Script InstallSQLDeveloper {
        #     GetScript = { return $false }
        #     TestScript = { return $false }
        #     SetScript = { powershell.exe G:\hmpps-delius-iaps-packer\scripts\windows\iaps\InstallSQLDeveloper.ps1 }
        # }
        # Script SetupODBCDSN {
        #     GetScript = { return $false }
        #     TestScript = { return $false }
        #     SetScript = { powershell.exe G:\hmpps-delius-iaps-packer\scripts\windows\iaps\SetupODBCDSN.ps1 }
        # }
        # Script InstallNDeliusInterface {
        #     GetScript = { return $false }
        #     TestScript = { return $false }
        #     SetScript = { powershell.exe G:\hmpps-delius-iaps-packer\scripts\windows\iaps\InstallNDeliusInterface.ps1 }
        # }
        # Script InstallIMInterface {
        #     GetScript = { return $false }
        #     TestScript = { return $false }
        #     SetScript = { powershell.exe G:\hmpps-delius-iaps-packer\scripts\windows\iaps\InstallIMInterface.ps1 }
        # }
        # Script ReEnableUserData {
        #     GetScript = { return $false }
        #     TestScript = { return $false }
        #     SetScript = { powershell.exe G:\hmpps-delius-iaps-packer\scripts\windows\iaps\ReEnableUserData.ps1 }
        # }

        # File SetDNSSearchSuffix {
        #     SourcePath = "G:\hmpps-delius-iaps-packer\scripts\windows\iaps\SetDNSSearchSuffix.ps1"
        #     DestinationPath = "C:\Setup\RunTimeConfig\SetDNSSearchSuffix.ps1"
        #     Ensure = "Present"
        # }
        # File ImportACMCertificates {
        #     SourcePath = "G:\hmpps-delius-iaps-packer\scripts\windows\iaps\ImportACMCertificates.ps1"
        #     DestinationPath = "C:\Setup\RunTimeConfig\ImportACMCertificates.ps1"
        #     Ensure = "Present"
        # }

        # File NginxConf {
        #     SourcePath = "G:\hmpps-delius-iaps-packer\files\windows\iaps\nginx.conf.tmpl"
        #     DestinationPath = "C:\Setup\Nginx\nginx.conf.tmpl"
        #     Ensure = "Present"
        # }
        # File SetupNginx {
        #     SourcePath = "G:\hmpps-delius-iaps-packer\scripts\windows\iaps\SetupNginx.ps1"
        #     DestinationPath = "C:\Setup\RunTimeConfig\SetupNginx.ps1"
        #     Ensure = "Present"
        # }

        ## TODO: manage route53 records through Terraform
        # File Route53Record {
        #     SourcePath = "G:\hmpps-delius-iaps-packer\scripts\windows\iaps\Route53Record.ps1"
        #     DestinationPath = "C:\Setup\RunTimeConfig\Route53Record.ps1"
        #     Ensure = "Present"
        # }

        # File HowToGuide {
        #     SourcePath = "C:\IAPS\S3\How-to-import-Database-connections-into-Oracle-SQL-Developer-from-XML.pdf"
        #     DestinationPath = "C:\Users\Public\Desktop\How-to-import-Database-connections-into-Oracle-SQL-Developer-from-XML.pdf"
        #     Ensure = "Present"
        # }
        # File CloudWatchConfig {
        #     SourcePath = "C:\IAPS\repo\CloudWatch\amazon-cloudwatch-agent.json"
        #     DestinationPath = "$Env:ProgramData\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent.json"
        #     Ensure = "Present"
        # }

    #     File ImportChainCertificates {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\scripts\windows\iaps\ImportChainCertificates.ps1"
    #         DestinationPath = "C:\Setup\RunTimeConfig\ImportChainCertificates.ps1"
    #         Ensure = "Present"
    #     }
    #     File UpdateIMInterface {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\scripts\windows\iaps\UpdateIMInterface.ps1"
    #         DestinationPath = "C:\Setup\RunTimeConfig\UpdateIMInterface.ps1"
    #         Ensure = "Present"
    #     }
    #     File UpdateNDeliusIMConfig {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\scripts\windows\iaps\UpdateNDeliusIMConfig.ps1"
    #         DestinationPath = "C:\Setup\RunTimeConfig\UpdateNDeliusIMConfig.ps1"
    #         Ensure = "Present"
    #     }
    #     File DisableServices {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\scripts\windows\iaps\DisableServices.ps1"
    #         DestinationPath = "C:\Setup\RunTimeConfig\DisableServices.ps1"
    #         Ensure = "Present"
    #     }
    #     File CreateScheduledTaskIAPSConfigBackup {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\scripts\windows\iaps\backups\CreateScheduledTaskIAPSConfigBackup.ps1"
    #         DestinationPath = "C:\Setup\RunTimeConfig\CreateScheduledTaskIAPSConfigBackup.ps1"
    #         Ensure = "Present"
    #     }
    #     File SetRegistryKeyPermissions {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\scripts\windows\iaps\SetRegistryKeyPermissions.ps1"
    #         DestinationPath = "C:\Setup\RunTimeConfig\SetRegistryKeyPermissions.ps1"
    #         Ensure = "Present"
    #     }
    #     File InstallPesterPoshSpec {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\scripts\windows\iaps\smoketests\Install-Pester-PoshSpec.ps1"
    #         DestinationPath = "C:\Setup\Testing\Install-Pester-PoshSpec.ps1"
    #         Ensure = "Present"
    #     }
    #     Script InstallPesterPoshSpec {
    #         GetScript = { return $false }
    #         TestScript = { return $false }
    #         SetScript = { powershell.exe G:\hmpps-delius-iaps-packer\scripts\windows\iaps\smoketests\Install-Pester-PoshSpec.ps1 }
    #     }
    #     File IMTests-Execute-Deploytime {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\iaps\smoketests\IMTests-Execute-Deploytime.ps1"
    #         DestinationPath = "C:\Setup\Testing\IMTests-Execute-Deploytime.ps1"
    #         Ensure = "Present"
    #     }
    #     File IMTests-Execute-Baketime {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\iaps\smoketests\IMTests-Execute-Baketime.ps1"
    #         DestinationPath = "C:\Setup\Testing\IMTests-Execute-Baketime.ps1"
    #         Ensure = "Present"
    #     }
    #     File IMTests-generic {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\iaps\smoketests\IMTests-generic.ps1"
    #         DestinationPath = "C:\Setup\Testing\IMTests-generic.ps1"
    #         Ensure = "Present"
    #     }
    #     File IMTests-PackerAMIBuild {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\iaps\smoketests\IMTests-PackerAMIBuild.ps1"
    #         DestinationPath = "C:\Setup\Testing\IMTests-PackerAMIBuild.ps1"
    #         Ensure = "Present"
    #     }
    #     File IMTests-Deploytime {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\iaps\smoketests\IMTests-Deploytime.ps1"
    #         DestinationPath = "C:\Setup\Testing\IMTests-Deploytime.ps1"
    #         Ensure = "Present"
    #     }
    #     File IMTests-Webservices {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\iaps\smoketests\IMTests-Webservices.ps1"
    #         DestinationPath = "C:\Setup\Testing\IMTests-Webservices.ps1"
    #         Ensure = "Present"
    #     }
    #     Script IMTestsExecuteBaketime {
    #         GetScript = { return $false }
    #         TestScript = { return $false }
    #         SetScript = { powershell.exe G:\hmpps-delius-iaps-packer\scripts\windows\scripts\windows\iaps\smoketests\IMTests-Execute-Baketime.ps1 }
    #     }
    #     File RestoreLatestIAPSConfig {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\scripts\windows\iaps\RestoreLatestIAPSConfig.ps1"
    #         DestinationPath = "C:\Setup\RestoreLatestIAPSConfig.ps1"
    #         Ensure = "Present"
    #     }
    #     File IAPSConnections {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\files\windows\iaps\connections.xml"
    #         DestinationPath = "C:\Users\Public\Desktop\connections.xml"
    #         Ensure = "Present"
    #     }
    #     File NginxCycleLogs {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\scripts\windows\iaps\backups\NginxCycleLogs.ps1"
    #         DestinationPath = "C:\Setup\NginxCycleLogs.ps1"
    #         Ensure = "Present"
    #     }
    #     File CreateScheduledTaskNginxLogsArchive {
    #         SourcePath = "G:\hmpps-delius-iaps-packer\scripts\windows\iaps\backups\CreateScheduledTaskNginxLogsArchive.ps1"
    #         DestinationPath = "C:\Setup\RunTimeConfig\CreateScheduledTaskNginxLogsArchive.ps1"
    #         Ensure = "Present"
    #     }
    }
}

if (! (Test-Path "C:\temp")) {
    mkdir C:\temp
}
cd C:\temp
IAPS -OutputPath .\mofs -ArtefactBucketName 'delius-iaps-development-artefacts'

 
