# Turn off the firewall as this will possibly interfere with Sia Node creation or other installations
$Profiles = @("Domain", "Public", "Private")
foreach ($Profile in $Profiles) {
  $NetFirewallProfile = Get-NetFirewallProfile -Profile $Profile
  if ($NetFirewallProfile.Enabled -ne $false) {
    Write-Output "Disabling firewall for profile $Profile"
    Set-NetFirewallProfile -Profile $Profile -Enabled False
  } else {
    Write-Verbose "Firewall already disabled for profile $Profile"
  }
}
