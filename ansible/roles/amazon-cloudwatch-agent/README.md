# Cloudwatch Agent Role

This role installs the Cloudwatch Agent on a Linux host and configures it to send metrics to Cloudwatch.

It will also install collectd and configure that to collect Oracle_Sids connection metrics.

These connection metrics will then be picked up by Cloudwatch if the `"collectd": {}` section of the cloudwatch agent is configured.

NOTE: At the moment this has NOT been tested on a Windows host. It may need to be tested as part of a deployment to a Windows host due to challenges with the module if run locally at an existing EC2 target. ONLY RUNS ON RedHat INSTANCES CURRENTLY

## Debugging on Linux

ssm onto the machine/instance and run the following command to find out the running status of the agent:

```bash
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -m ec2 -a status
```

run the following to check the config has been accepted:

```bash
cat /opt/aws/amazon-cloudwatch-agent/logs/configuration-validation.log
```

## Debugging everything

https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/troubleshooting-CloudWatch-Agent.html