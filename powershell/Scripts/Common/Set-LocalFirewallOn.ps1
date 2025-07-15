$Profiles = @("Domain", "Public", "Private")
foreach ($Profile in $Profiles) {
  $NetFirewallProfile = Get-NetFirewallProfile -Profile $Profile
  if ($NetFirewallProfile.Enabled -ne $true) {
    if ($env:DRYRUN -eq "true") {
      Write-Host "DRYRUN: Enabling firewall for profile $Profile"
    } else {
      Write-Host "Enabling firewall for profile $Profile"
      Set-NetFirewallProfile -Profile $Profile -Enabled True
    }
  } else {
    Write-Host "Firewall already enabled for profile $Profile"
  }
}
