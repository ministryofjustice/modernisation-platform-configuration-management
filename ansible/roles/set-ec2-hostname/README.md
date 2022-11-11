Set EC2 hostname to a short name, i.e. remove the domain name.

This is for legacy applications which may have hostname length restrictions.

By default, the role sets the name to the existing DNS name, i.e. just
strips the FQDN.

Alternatively, if you set `use_name_as_hostname=true`, it will set the
hostname to the tag:Name value. In this scenario, be sure to add a DNS
entry to the mod platform provided internal DNS zone, and run domain-search
role on all instances that will access the instance using this hostname.
This allows more user friendly hostnames to be used.

Don't set `use_name_as_hostname=true` on autoscaling groups with more than
one instance.
