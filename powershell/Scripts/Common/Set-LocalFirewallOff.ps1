# Turn off the firewall as this will possibly interfere with Sia Node creation or other installations
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled False
