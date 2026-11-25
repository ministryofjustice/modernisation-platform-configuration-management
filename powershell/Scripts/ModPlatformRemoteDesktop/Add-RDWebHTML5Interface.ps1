Import-Module RemoteDesktop
$BrokerCertInfo = Get-RDCertificate -Role RDRedirector -ConnectionBroker $env:COMPUTERNAME

if (-not $BrokerCertInfo -or -not $BrokerCertInfo.Thumbprint) {
    Write-Error "Could not retrieve RDRedirector cert"
}
$Thumbprint = $BrokerCertInfo.Thumbprint -replace '\s', ''

if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {
    Write-Output "Installing NuGet PackageProvider"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
} else {
    Write-Verbose "NuGet PackageProvider already installed"
}

$PSGet = Get-Module -ListAvailable -Name PowerShellGet | Sort-Object Version -Descending | Select-Object -First 1
if (-not $PSGet -or $PSGet.Version -lt [version]"2.2.5") {
    Write-Output "Updating PSGet module"
    Install-Module -Name PowerShellGet -MinimumVersion 2.2.5 -Force -AllowClobber

    Remove-Module PowerShellGet -Force -ErrorAction SilentlyContinue
    Import-Module PowerShellGet -MinimumVersion 2.2.5 -Force
} else {
    Write-Verbose "PowerShellGet ($($PSGet.Version)) is already up to date"
}

if (-not (Get-Module -ListAvailable -Name RDWebClientManagement)) {
    Write-Host "Installing RDWebClientManagement module"
    Install-Module -Name RDWebClientManagement -Force -AllowClobber -AcceptLicense
} else {
    Write-Verbose "RDWebClientManagement module is already installed."
}
Import-Module RDWebClientManagement -Force

$InstalledPackages = Get-RDWebClientPackage -ErrorAction SilentlyContinue
if (-not $InstalledPackages) {
    Write-Host "Downloading and installing RDWebClientPackage"
    Install-RDWebClientPackage
} else {
    Write-Verbose "RDWebClientPackage is already installed"
}

$CurrentBrokerCert = Get-RDWebClientBrokerCert -ErrorAction SilentlyContinue
$NeedsPublish = $false
if (-not $CurrentBrokerCert -or ($CurrentBrokerCert.Thumbprint -ne $Thumbprint)) {
    Write-Output "Updating RDWebClientBrokerCert to $Thumbprint"
    $Cert = Get-ChildItem -Path "Cert:\LocalMachine\My\$Thumbprint" -ErrorAction Stop
    $TempCertPath = Join-Path $env:TEMP "broker_temp_$([guid]::NewGuid()).cer"
    try {
        Export-Certificate -Cert $Cert -FilePath $TempCertPath -Type CERT | Out-Null
        Import-RDWebClientBrokerCert -Path $TempCertPath
        $NeedsPublish = $true
    }
    finally {
        if (Test-Path $TempCertPath) {
            Remove-Item -Path $TempCertPath -Force
        }
    }
} else {
    Write-Verbose "RDWebClientBrokerCert already matches active Broker thumbprint ($Thumbprint)"
}

$PublishedProd = Get-RDWebClientPackage | Where-Object { $_.Published -eq $true -and $_.Type -eq 'Production' }
if (-not $PublishedProd -or $NeedsPublish) {
    Write-Output "Publishing RDWebClientPackage"
    Publish-RDWebClientPackage -Type Production -Latest
} else {
    Write-Verbose "RDWebClientPackage is already published and up to date"
}
