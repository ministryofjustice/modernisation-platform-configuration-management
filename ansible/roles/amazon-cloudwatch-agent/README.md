# Cloudwatch Agent Role

This role installs the Cloudwatch Agent on a Linux host and configures it to send metrics to Cloudwatch.

If the group_vars for a host has the variable `cloudwatch_agent_configs` defined then this will deploy additional cloudwatch agent config files to the host. See files in /templates for examples. 

Amazon Cloudwatch Agent config exection and start order is: 

    1. ansible_system == 'linux' (the default ansible_system i.e. linux) via `/templates/linux.json.j2`
    2. collectd config if collectd is already installed via `/templates/agen_config_collectd.json.j2`
    3. loops through values of `cloudwatch_agent_configs` in group_vars and deploys them to the host
    
e.g. if you have a group_vars entry like this:

```
cloudwatch_agent_configs:
  - nomis-db
```  

* IMPORTANT: the collectd role has to be run first if additional metrics supplied/created by collectd are needed! 


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

IMPORTANT: Worth knowing about setting up Cloudwatch Agent to monitor log files. DO NOT USE WILDCARDS in file definitions for the path of a log. This causes the agent to use increasing amounts of memory as it attempts to monitor ALL the log files in the directory... 

### Debugging continued!

Definitely add `debug: true` to the cloudwatch agent config file to see what's going on. It may also be worth sending all the values to a custom namespace to help identify what you're looking at versus the default CWAgent namespace! Unless you specify otherwise cloudwatch agent logs go to `/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log`

Collectd relies on plugins, the most important one related to Cloudwatch is the 'network' plugin which posts the metrics data to a UDP endpoint. Cloudwatch picks metrics up from there and sends them on to cloudwatch. 

Intro to Collectd networking [here](https://collectd.org/wiki/index.php/Networking_introduction)

In the linux.json.j2 file the `append_dimensions` section needs to exist at the "global" level as well as the metrics level for these additional dimensions to be added to the metrics. This is not obvious from the documentation.

## Finding metrics in Cloudwatch

Metrics collected by the Cloudwatch agent will appear in the 'metrics' panel as <cloudwatch_agent_config/metrics/metrics_collected/collectd/name_prefix>_<collectd_plugin_name>_value e.g. collectd_cpu_value, collectd_exec_value.

Cloudwatch metrics are easily filtered by instance_id so you can see all the metrics for a particular instance.

## Finding Logs in Cloudwatch

Logs are organised into Log Groups which have to be independently specified in the tf. locals for each environment. This is to prevent arbitrary EC2 instances from creating their own logs groups. Deleting them is a pain so this restriction is in place to prevent that.

Log Groups are easily identified by name and filtered by instance_id.

# Cloudwatch Agent on Windows

This is currently being deployed from the user-data script in the modernisation-platform-environment repo. It's not ideal but it works. This avoids having to get ansible running on the Windows hosts using the ansibe ssm module or using Lambdas as a host environment for running ansible.

## Finding metrics to Monitor using Powershell

Counter setnames are logicaldisk, memory, network interface, processor and system. It's easiest to find these using powershell:

```powershell
Get-Counter -ListSet * | Where-Object -FilterScript { $PSItem.counter
setname -match 'logicaldisk'} | Select-Object -Property Counter -ExpandProperty Counter
```

Be aware that some Windows metrics will appear in the list in the AWS Cloudwatch Console as <CounterSetName> <Metric Name> e.g. Memory % CPU Available. In some cases it's actually preferable to rename the metric in the config but not all metrics can be renamed. 
