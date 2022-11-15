Set EC2 hostname to a short name, i.e. remove the domain name.

This is for legacy applications which may have hostname length restrictions.

For individual EC2 instances, the role sets the hostname to `tag:Name`.
For autoscaling groups, the DNS name is used minus the domain.

For individual EC2 instances, ensure a DNS entry is added to the mod
platform internal DNS zone, and run domain-search role on all instances
that will access the instance using this hostname.
