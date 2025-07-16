$ErrorActionPreference = "Stop"
$RegistryPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon"
$LegalNoticeCaption = "IMPORTANT"
$LegalNoticeText = "This system is restricted to authorized users only. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information"

if (-NOT (Test-Path $RegistryPath)) {
    Write-Output "Creating Login registry item: $RegistryPath"
    New-Item -Path $RegistryPath -Force | Out-Null
}

$ItemProperty = Get-ItemProperty -Path $RegistryPath -Name LegalNoticeCaption -ErrorAction SilentlyContinue
if ($null -eq $ItemProperty -or $ItemProperty.LegalNoticeCaption -ne $LegalNoticeCaption) {
    Write-Output "Setting Login Legal Notice Caption"
    New-ItemProperty -Path $RegistryPath -Name LegalNoticeCaption -Value $LegalNoticeCaption -PropertyType String -Force | Out-Null
} else {
    Write-Verbose "Login Legal Notice Caption already set"
}

$ItemProperty = Get-ItemProperty -Path $RegistryPath -Name LegalNoticeText -ErrorAction SilentlyContinue
if ($null -eq $ItemProperty -or $ItemProperty.LegalNoticeText -ne $LegalNoticeText) {
    Write-Output "Setting Loging Legal Notice Text"
    New-ItemProperty -Path $RegistryPath -Name LegalNoticeText -Value $LegalNoticeText -PropertyType String -Force | Out-Null
} else {
    Write-Verbose "Login Legal Notice Text already set"
}
