function Install-BIPWindowsClient43 {

    # Check if BIP Windows Client 4.3 is already installed
    $installDir = "C:\Program Files (x86)\SAP BusinessObjects"
    if (Test-Path $installDir) {
        Write-Host "BIP Windows Client 4.3 is already installed."
        return
    }

    $WorkingDirectory = "C:\Software"

    if (-not (Test-Path $WorkingDirectory)) {
        New-Item -ItemType Directory -Path $WorkingDirectory -Force
    }

    $BIPClientTools43ResponseFileContent = @"
### Installation Directory
Installdir=C:\Program Files (x86)\SAP BusinessObjects\
### Language Packs Selected to Install
selectedlanguagepacks=en
### Setup UI Language
setupuilanguage=en
features=WebI_Rich_Client,Business_View_Manager,Report_Conversion,Universe_Designer,QAAWS,InformationDesignTool,Translation_Manager,DataFederationAdministrationTool,biwidgets,ClientComponents,JavaSDK,WebSDK,DotNetSDK,CRJavaSDK,DevComponents,DataFed_DataAccess,HPNeoView_DataAccess,MySQL_DataAccess,GenericODBC_DataAccess,GenericOLEDB_DataAccess,GenericJDBC_DataAccess,MaxDB_DataAccess,SalesForce_DataAccess,Netezza_DataAccess,Microsoft_DataAccess,Ingres_DataAccess,Greenplum_DataAccess,IBMDB2,Informix_DataAccess,Progress_Open_Edge_DataAccess,Oracle_DataAccess,Sybase_DataAccess,TeraData_DataAccess,SAPBW_DataAccess,SAP_DataAccess,PersonalFiles_DataAccess,JavaBean_DataAccess,OpenConnectivity_DataAccess,HSQLDB_DataAccess,Derby_DataAccess,Essbase_DataAccess,PSFT_DataAccess,JDE_DataAccess,Siebel_DataAccess,EBS_DataAccess,DataAccess
"@

    Set-Location -Path $WorkingDirectory

    Get-Installer -Key $BIPWindowsClient43 -Destination (".\" + $BIPWindowsClient43)

    $BIPClientTools43ResponseFileContent | Out-File -FilePath "$WorkingDirectory\bip43_response.ini" -Force -Encoding ascii

    choco install winrar -y

    New-Item -ItemType Directory -Path "$WorkingDirectory\BIP43" -Force

    Clear-PendingFileRenameOperations

    # Extract the BIP 4.3 self-extracting archive using WinRAR's UnRAR command line tool
    Start-Process -FilePath "C:\Program Files\WinRAR\UnRAR.exe" -ArgumentList "/wait x -o+ $WorkingDirectory\$BIPWindowsClient43 $WorkingDirectory\BIP43" -Wait -NoNewWindow

    $BIPClientTools43Params = @{
        FilePath     = "$WorkingDirectory\BIP43\setup.exe"
        ArgumentList = "/wait", "-r $WorkingDirectory\bip43_response.ini"
        Wait         = $true
        NoNewWindow  = $true
    }

    Start-Process @BIPClientTools43Params

    # Set up shortcuts for 4.3 client tools
    $BIP43Path = "C:\Program Files (x86)\SAP BusinessObjects\SAP BusinessObjects Enterprise XI 4.0\win64_x64\"

    # List is incomplete, add more executables as needed
    $executables = @(
        @{
            "Name" = "Designer"
            "Exe"  = "designer.exe"
        },
        @{
            "Name" = "Information Design Tool"
            "Exe"  = "InformationDesignTool.exe"
        }
    )

    # Path to all users' desktop
    $AllUsersDesktop = [Environment]::GetFolderPath('CommonDesktopDirectory')

    # Create folders on all users' desktop
    $Client43Folder = Join-Path -Path $AllUsersDesktop -ChildPath "4.3 Client Tools"

    New-Item -ItemType Directory -Path $Client43Folder -Force

    # Create shortcuts for each executable if the target exists
    $WScriptShell = New-Object -ComObject WScript.Shell

    foreach ($executable in $executables) {

        # Shortcuts for 4.3 Client
        $TargetPath43 = Join-Path -Path $BIP43Path -ChildPath $executable.Exe
        if (Test-Path $TargetPath43) {
            $ShortcutPath43 = Join-Path -Path $Client43Folder -ChildPath ($executable.Name + ".lnk")
            $Shortcut43 = $WScriptShell.CreateShortcut($ShortcutPath43)
            $Shortcut43.TargetPath = $TargetPath43
            $Shortcut43.IconLocation = $TargetPath43
            $Shortcut43.Save()
        }
        else {
            Write-Host "Executable not found: $TargetPath43"
        }
    }
}

function Clear-PendingFileRenameOperations {
    $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
    $regKey = "PendingFileRenameOperations"

    if (Get-ItemProperty -Path $regPath -Name $regKey -ErrorAction SilentlyContinue) {
        try {
            Remove-ItemProperty -Path $regPath -Name $regKey -Force -ErrorAction Stop
            Write-Host "Successfully removed $regKey from the registry."
        }
        catch {
            Write-Warning "Failed to remove $regKey. Error: $_"
        }
    }
    else {
        Write-Host "$regKey does not exist in the registry. No action needed."
    }
}

function Get-Installer {
    param (
        [Parameter(Mandatory)]
        [string]$Key,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $s3Params = @{
        BucketName = $S3Bucket
        Key        = ($WindowsClientS3Folder + "/" + $Key)
        File       = $Destination
        Verbose    = $true
    }

    Read-S3Object @s3Params
}

$S3Bucket                   = "mod-platform-image-artefact-bucket20230203091453221500000001"
$WindowsClientS3Folder      = "hmpps/ncr-packages"
$BIPWindowsClient43         = "BIPLATCLNT4304P_500-70005711.EXE" # Client tools 4.3 SP 4 Patch 5

Install-BIPWindowsClient43

# NOTE: Just keeping a record of these versions as this info is difficult to find in the SAP download portal
# $BIPWindowsClient43 = "BIPLATCLNT4303P_500-70005711.EXE" # Client tools 4.3 SP 3 Patch 5
# $BIPWindowsClient43 = "BIPLATCLNT4301P_1200-70005711.EXE" # Client tool 4.3 SP 1 Patch 12 as per Azure PDMR2W00014
# $BIPWindowsClient43 = "BIPLATCLNT4303P_300-70005711.EXE" # Client tool 4.3 SP 3 Patch 3
# $BIPWindowsClient42 # "5104879_1.ZIP" # Client tool 4.2 SP 9 <- needs a different installer approach
