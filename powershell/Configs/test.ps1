# Install-Module -Name powershell-yaml -Force -SkipPublisherCheck

# Import-Module ModPlatformAD -Force

Import-Module powershell-yaml -Force

# Load YAML
$config = Get-Content -Raw -Path ADConfigDevTest.yaml | ConvertFrom-Yaml

foreach ($ou in $config.ActiveDirectory.OUs) {
    Write-Host "processing OU $($ou.name)"
    if ($ou.gpos) {
        foreach ($gpo in $ou.gpos) {
            Write-Host "processing GPO $gpo"
        }
    }
}
