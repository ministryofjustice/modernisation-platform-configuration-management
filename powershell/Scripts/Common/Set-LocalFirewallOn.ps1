# Turn on local instance firewall
$Profiles = @("Domain", "Public", "Private")
foreach ($Profile in $Profiles) {
  $NetFirewallProfile = Get-NetFirewallProfile -Profile $Profile
  if ($NetFirewallProfile.Enabled -ne $true) {
    Write-Output "Enabling firewall for profile $Profile"
    Set-NetFirewallProfile -Profile $Profile -Enabled False
  } else {
    Write-Verbose "Firewall already enabled for profile $Profile"
  }
}
