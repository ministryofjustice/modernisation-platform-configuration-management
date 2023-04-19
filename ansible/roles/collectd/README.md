# Collectd

Installs collectd and configures it based on the values in group_vars `collectd_metric_configs` variable. See server_type_nomis_db for an example.

1. reads values of `collectd_metric_configs` from group_vars

e.g. 
```    
collectd_metric_configs:
  - nomis-web
```

2. loops through values of files/[collectd_metric_configs] and templates/[collectd_metric_configs] deploys them to the host if the relevant files exist
    
3. deploys files/linux.conf and templates/linux.sh.j2 to the host by default if collectd_metric_configs is not defined

* IMPORTANT: to pick up service metrics from windows hosts it'd probably be easier to use PowerShell and scheduled tasks to post the metrics directly to Cloudwatch. This hasn't been implemented anywhere yet though.
## Debugging Collectd

Probably the easiest thing to do is un-comment the 'logfile' plugin sections in collectd.conf.j2 and reload collectd via `sudo systemctl restart collectd.service`

Then you can `cat /var/log/collectd.log` to see what's going on. Also `sudo cat /var/log/messages | grep collectd` to see if there are any errors. This is especially useful for plugins not loading or configuration issues generally.

You can also install tcpdump on the instance `sudo yum install tcpdump` and run `sudo tcpdump -vv -A -i lo -n udp port 25826 | grep oracle-health` to see the metrics which should be picked up by the Cloudwatch agent locally.

Further collectd Troubleshooting [here](https://collectd.org/wiki/index.php/Troubleshooting)

## Collectd gotchas and how things work

1. *.conf files must have an empty line at the end to load, otherwise collectd won't start...

2. formatting for the exec message (sent to localhost udp port 25826) is very important. It MUST be in the format "PUTVAL $HOSTNAME/exec-<name_of_metric>/guage-$signifier. Values after exec- and guage- (or other value type) cannot use '-' characters or spaces otherwise the exec plugin will deliver a mal-formed message. 
