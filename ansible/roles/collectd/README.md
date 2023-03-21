# Collectd
## Debugging Collectd

Probably the easiest thing to do is un-comment the 'logfile' plugin sections in collectd.conf.j2 and reload collectd via `sudo systemctl restart collectd.service`

Then you can `cat /var/log/collectd.log` to see what's going on. Also `sudo cat /var/log/messages | grep collectd` to see if there are any errors. This is especially useful for plugins not loading or configuration issues generally.

You can also install tcpdump on the instance `sudo yum install tcpdump` and run `sudo tcpdump -vv -A -i lo -n udp port 25826 | grep oracle-health` to see the metrics which should be picked up by the Cloudwatch agent locally.

Further collectd Troubleshooting [here](https://collectd.org/wiki/index.php/Troubleshooting)

## Collectd gotchas and how things work

1. *.conf files must have an empty line at the end to load, otherwise collectd won't start...
2. In the agent_config_linux.json.j2 file the `append_dimensions` section needs to exist at the "global" level as well as the metrics level for these additional dimensions to be added to the metrics. This is not obvious from the documentation.
3. formatting for the exec message (sent to localhost udp port 25826) is very important. It MUST be in the format "PUTVAL $HOSTNAME/exec-<name_of_metric>/guage-$signifier. Values after exec- and guage- (or other value type) cannot use '-' characters or spaces otherwise the exec plugin will deliver a mal-formed message. 

