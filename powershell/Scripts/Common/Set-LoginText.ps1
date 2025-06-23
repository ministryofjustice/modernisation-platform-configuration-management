function Set-LoginText {
    param (
        [Parameter(Mandatory)]
        [hashtable]$Config
    )
    # Apply to all environments that aren't on the domain
    $ErrorActionPreference = "Stop"
    Write-Output "Add Legal Notice"

    $RegistryPath = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\winlogon"
    $LegalNoticeCaption = "IMPORTANT"
    $LegalNoticeText = "This system is restricted to authorized users only. Individuals who attempt unauthorized access will be prosecuted. If you are unauthorized terminate access now. Click OK to indicate your acceptance of this information"

    if (-NOT (Test-Path $RegistryPath)) {
        Write-Output " - Registry path does not exist, creating"
        New-Item -Path $RegistryPath -Force | Out-Null
    }

    Write-Output " - Set Legal Notice Caption"
    New-ItemProperty -Path $RegistryPath -Name LegalNoticeCaption -Value $LegalNoticeCaption -PropertyType String -Force

    Write-Output " - Set Legal Notice Text"
    New-ItemProperty -Path $RegistryPath -Name LegalNoticeText -Value $LegalNoticeText -PropertyType String -Force
}
