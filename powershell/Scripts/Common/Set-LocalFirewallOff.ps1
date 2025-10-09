# Turn off the firewall as this will possibly interfere with Sia Node creation or other installations
$Profiles = @('Domain', 'Public', 'Private')
foreach ($FirewallProfile in $Profiles) {
  $NetFirewallProfile = Get-NetFirewallProfile -Profile $FirewallProfile
  if ($NetFirewallProfile.Enabled -ne $false) {
    Write-Output "Disabling firewall for profile: $FirewallProfile"
    Set-NetFirewallProfile -Profile $FirewallProfile -Enabled False
  }
  else {
    Write-Verbose "Firewall already disabled for profile: $FirewallProfile"
  }
}
