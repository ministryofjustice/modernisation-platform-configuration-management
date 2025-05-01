# Turn on local instance firewall
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True
