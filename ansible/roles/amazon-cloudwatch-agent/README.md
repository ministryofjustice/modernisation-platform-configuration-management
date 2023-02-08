# Cloudwatch Agent Role

This role installs the Cloudwatch Agent on a Linux host and configures it to send metrics to Cloudwatch.

It will also install collectd and configure that to collect Oracle_Sids connection metrics.

These connection metrics will then be picked up by Cloudwatch if the `"collectd": {}` section of the cloudwatch agent is configured.

IMPORTANT: This role is inactive for Windows hosts as we have not yet implemented a way to run ansible at them. At some point we will probably run this from an AWS Lambda function. For now we are using the Windows Jumpserver init script in the modernisation-platform-environment repo

# Cloudwatch Agent
## Debugging on Linux

ssm onto the machine/instance and run the following command to find out the running status of the agent:

```bash
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
```

run the following to check the config has been accepted:

```bash
cat /opt/aws/amazon-cloudwatch-agent/logs/configuration-validation.log
```

## Debugging Cloudwatch Agent

https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/troubleshooting-CloudWatch-Agent.html

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

### Debugging continued!

definitely add `debug: true` to the cloudwatch agent config file to see what's going on. It may also be worth sending all the values to a custom namespace to help identify what you're looking at versus the default CWAgent namespace! Unless you specify otherwise cloudwatch agent logs go to `/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log`

Collectd relies on plugins, the most important one related to Cloudwatch is the 'network' plugin which posts the metrics data to a UDP endpoint. Cloudwatch picks metrics up from there and sends them on to cloudwatch. 

Intro to Collectd networking [here](https://collectd.org/wiki/index.php/Networking_introduction)

## Finding metrics in Cloudwatch

Metrics collected by the Cloudwatch agent will appear in the 'metrics' panel as <cloudwatch_agent_config/metrics/metrics_collected/collectd/name_prefix>_<collectd_plugin_name>_value e.g. collectd_cpu_value, collectd_exec_value.

Cloudwatch metrics are easily filtered by instance_id so you can see all the metrics for a particular instance.

### collectd_exec-db_connected: Oracle_Sids connection check

If this returns a value of 1 then the database is not connected. If it returns a value of 0 then the database is connected.

### collectd_exec-batch_error: Oracle Batch Error check

If this returns a value of 1 there there is either a long running batch job or a batch job has failed.

## Finding Logs in Cloudwatch
<!-- coming soon! Add a link to where this lives in Confluence  -->

# Cloudwatch Agent on Windows

This is currently being deployed from the init script in the modernisation-platform-environment repo. It's not ideal but it works. This avoids having to get ansible running on the Windows hosts using the ansibe ssm module or using Lambdas as a host environment for running ansible.

## Finding metrics to Monitor using Powershell

Counter setnames are logicaldisk, memory, network interface, processor and system. It's easiest to find these using powershell:

```powershell
Get-Counter -ListSet * | Where-Object -FilterScript { $PSItem.counter
setname -match 'logicaldisk'} | Select-Object -Property Counter -ExpandProperty Counter
```





