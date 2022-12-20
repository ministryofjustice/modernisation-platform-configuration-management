param(
    [Parameter(Mandatory=$true)]
    [String]$ArtefactsPath='C:\Setup\artefacts',
    [String]$CodePath='C:\Setup\code'
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Extract setup files from 7z archive
try {
    Start-Process $env:ProgramFiles\7-Zip\7z.exe "x -oC:\setup\oracle\install -aos $ArtefactsPath\OracleClient\Oracle_12c_Win32_12.1.0.2.0.7z" -Wait -Verb RunAs
}
catch [Exception] {
    Write-Host ('Failed to extract Oracle client setup using 7z')
    echo $_.Exception|format-list -force
    exit 1
}
# Add required patches for x86 client
# Edit oaparam file to use 32bit vcredist
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

# # Install 32bit client from answer file, using runas administrator verb
# # See: https://docs.oracle.com/database/121/NTCLI/advance.htm#NTCLI1347
try {
    if (!(Test-Path C:\app)) { 
        $oracleanswerfile = join-path -path $CodePath -childPath OracleClient.rsp
        Start-Process -FilePath 'C:\Setup\Oracle\Install\Oracle_12c_Win32_12.1.0.2.0\client32\setup.exe' -Verb RunAs -ArgumentList "-silent -nowelcome -nowait -noconfig 'ORACLE_HOSTNAME=$env:computername' -responseFile $oracleanswerfile" -Wait
    }
    if (!(Test-Path C:\app)) { 
        Write-Host('Error - Something went wrong installing Oracle client - unable to find install path')
        exit 1
    }
}
catch [Exception] {
    Write-Host ('Failed installing Oracle Client')
    echo $_.Exception|format-list -force
    exit 1
}

# Configure net connections
try {
    $tnsnameorafile = 'C:\app\client\Administrator\product\12.1.0\client_1\network\admin\tnsnames.ora'
    Copy-Item -Path (join-path -path $CodePath -childPath tnsnames.ora.tmpl) -Destination $tnsnameorafile

    $sqlnetorafile = 'C:\app\client\Administrator\product\12.1.0\client_1\network\admin\sqlnet.ora'
    Copy-Item -Path (join-path -path $CodePath -childPath sqlnet.ora.tmpl) -Destination $sqlnetorafile
}
catch [Exception] {
    Write-Host ('Error - Failed to create ora file: $tnsnameorafile')
    echo $_.Exception|format-list -force
    exit 1
}

try {
    Write-Host ('Update Oracle NLS_LANG reg value')
    Set-ItemProperty -path "HKLM:\SOFTWARE\Wow6432Node\ORACLE\KEY_OraClient12Home1_32bit" -name "NLS_LANG" -value "ENGLISH_UNITED KINGDOM.WE8MSWIN1252" 
}
catch [Exception] {
    Write-Host ('Error - Failed to update oracle NLS_LANG value')
    echo $_.Exception|format-list -force
    exit 1
}

# #//TODO: possibly required? (prob not as Packer installs as Administrator user, manually prod built server via login as i2nadmin user)

# # Set-ItemProperty -path "HKLM:\SOFTWARE\Wow6432Node\ORACLE\KEY_OraClient12Home1_32bit" -name "ORACLE_BASE" -value "C:\app\client\i2nadmin" 
# # Set-ItemProperty -path "HKLM:\SOFTWARE\Wow6432Node\ORACLE\KEY_OraClient12Home1_32bit" -name "ORACLE_HOME" -value "C:\app\client\i2nadmin\product\12.1.0\client_1" 
# # Set-ItemProperty -path "HKLM:\SOFTWARE\Wow6432Node\ORACLE\KEY_OraClient12Home1_32bit" -name "OLEDB" -value "C:\app\client\i2nadmin\product\12.1.0\client_1\oledb\mesg" 
# # Set-ItemProperty -path "HKLM:\SOFTWARE\Wow6432Node\ORACLE\KEY_OraClient12Home1_32bit" -name "MSHELP_TOOLS" -value "C:\app\client\i2nadminC:\app\client\i2nadmin\product\12.1.0\client_1\MSHELP" 
# # Set-ItemProperty -path "HKLM:\SOFTWARE\Wow6432Node\ORACLE\KEY_OraClient12Home1_32bit" -name "SQLPATH" -value "C:\app\client\i2nadmin\product\12.1.0\client_1\dbs" 

 
