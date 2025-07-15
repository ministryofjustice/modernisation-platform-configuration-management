# Turn off the firewall as this will possibly interfere with Sia Node creation or other installations
$Profiles = @("Domain", "Public", "Private")
foreach ($Profile in $Profiles) {
  $NetFirewallProfile = Get-NetFirewallProfile -Profile $Profile
  if ($NetFirewallProfile.Enabled -ne $false) {
    if ($env:DRYRUN -eq "true") {
      Write-Host "DRYRUN: Disabling firewall for profile $Profile"
    } else {
      Write-Host "Disabling firewall for profile $Profile"
      Set-NetFirewallProfile -Profile $Profile -Enabled False
    }
  } else {
    Write-Host "Firewall already disabled for profile $Profile"
  }
}
