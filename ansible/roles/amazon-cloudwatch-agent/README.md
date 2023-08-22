# FIXME: this page needs an extensive re-write

# Cloudwatch Agent Role

This role installs the Cloudwatch Agent on a Linux host and configures it to send metrics to Cloudwatch.

If the group_vars for a host has the variable `cloudwatch_agent_configs` defined then this will deploy additional cloudwatch agent config files to the host. See files in /templates for examples. 

Amazon Cloudwatch Agent config exection and start order is: 

    1. ansible_system == 'linux' (the default ansible_system i.e. linux) via `/templates/linux.json.j2`
    2. loops through values of `cloudwatch_agent_configs` in group_vars and deploys them to the host
    
e.g. if you have a group_vars entry like this:

```
cloudwatch_agent_configs:
  - nomis-db
```  
  
  then the file `templates/nomis-db.json.j2` will be deployed to the host.  

# Cloudwatch Agent

Metrics sent to Cloudwatch will all appear in the default CWAgent namespace
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

IMPORTANT: DO NOT USE WILDCARDS in file definitions for the path of a log. This causes the agent to use increasing amounts of memory as it attempts to monitor ALL the log files in the directory... 


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
