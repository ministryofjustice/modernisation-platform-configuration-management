# Collectd

Installs collectd and configures it based on the values in group_vars `collectd_metric_configs` variable. See server_type_nomis_db for an example.

Collectd is able to run scripts and perform other tasks based on plugins. The scripts are run by the exec plugin and the results are made available to the Cloudwatch agent on the same host via the network plugin. The Cloudwatch agent then sends the metrics to Cloudwatch.

The common plugins are defined in collectd.conf.j2 (network plugin being the most important) with additional plugins pulled in by the statement 
`Include "/etc/collectd.d` in the main collectd.conf file. 

The collectd_configure task does the following:

1. reads values of `collectd_metric_configs` from group_vars, for example:

```    
collectd_metric_configs:
  - nomis-db
```

2. loops through values of files/[collectd_metric_configs] and templates/[collectd_metric_configs] deploys them to the host if the relevant files exist
    
3. files/linux.conf and templates/linux.sh.j2 are deployed to the host by default if additional collectd_metric_configs are not defined


## Debugging Collectd

Probably the easiest thing to do is un-comment the 'logfile' plugin sections in collectd.conf.j2 and reload collectd via `sudo systemctl restart collectd.service`

Then you can `cat /var/log/collectd.log` to see what's going on. Also `sudo cat /var/log/messages | grep collectd` to see if there are any errors. This is especially useful for plugins not loading or configuration issues generally.

You can also install tcpdump on the instance `sudo yum install tcpdump` and run `sudo tcpdump -vv -A -i lo -n udp port 25826 | grep oracle-health` to see the metrics which should be picked up by the Cloudwatch agent locally.

Further collectd Troubleshooting [here](https://collectd.org/wiki/index.php/Troubleshooting)

## Collectd gotchas and how things work

1. *.conf files must have an empty line at the end to load, otherwise collectd won't start...

2. formatting for the exec message (sent to localhost udp port 25826) is very important. It MUST be in the format "PUTVAL $HOSTNAME/exec-<name_of_metric>/guage-$signifier. Values after exec- and guage- (or other value type) cannot use additional '-' characters or spaces otherwise the exec plugin will deliver a mal-formed message. 

## Collectd and Selinux

There is an additional task specifically to create a selinux policy for collectd. This is because collectd runs scripts via the exec plugin and selinux will block this by default. 

Having loging for collectd is NOT enabled. Most of the useful information goes to /var/log/messages anyway or with selinux to /var/log/audit/audit.log where you can see what's being blocked in relation to collectd

There are selinux exceptions for collectd when it comes to Rhel 7 & 8. It _seems_ this isn't needed for Rhel 6 but there is an existing task to automatically scan the audit.log for issues and then create a policy file. 

### Some useful selinux commands for troubleshooting

`ls -Z /file/path` will tell you the selinux context of a file, this is useful to understand what context a file needs to be in to be accessed by a particular process

Once you have found an AVC denial message in /var/log/audit/audit.log you can use the audit2allow command to create a policy file to allow the process to access the file.

`echo 'denial message' | audit2allow -M <name_of_policy_file>` this will create a *.te file and a *.pp file which you can add to the selinux policy by running `semodule -i <name_of_policy_file>.pp` directly. NOTE: that there are permissions issues with running this in certain directories so you may need to run this command in /usr/tmp or similar.

If/when there are additional instances of this please add the settings back to the relevant collectd_selinux_policy_rhel_(version).te file and re-run the ansible task to create the policy file.

At some point we may simply decide to place the whole collectd_t domain into permissive mode.

```
- name: change the collectd_t domain to permissive
  community.general.selinux_permissive:
    type: collectd_t
    permissive: true
```

