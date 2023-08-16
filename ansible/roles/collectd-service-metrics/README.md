# Role to configure monitoring for service state using collectd

The collectd 'exec' plugin is being used here to run a monitored_services.sh script which checks the status of each service in the `collectd_monitored_services` list and returns a 0 (running) or 1 (not running) value for each. The script is in the templates directory and is copied to the host by the role. The script is then called by the exec plugin and the output is sent to the local collectd port.

Anything we want to monitor should be set up as a service (see weblogic-healthcheck for exampe) and then added to the `collectd_monitored_services` list in group_vars. This will over-ride the default list in defaults/main.yml which is only amazon-cloudwatch-agent and amazon-ssm-agent.

### Debugging

Most issues with collectd end up in /var/log/messages, including where selinux is blocking collectd from running the script.

Definitely add `debug: true` to the cloudwatch agent config file to see what's going on. It may also be worth sending all the values to a custom namespace to help identify what you're looking at versus the default CWAgent namespace!

Unless you specify otherwise cloudwatch agent logs go to `/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log` which is also worth checking to make sure the messages it's trying to pick up from the collectd port are making sense.

Collectd relies on plugins, the most important one related to Cloudwatch is the 'network' plugin which posts the metrics data to a UDP endpoint. Cloudwatch picks metrics up from there and sends them on to cloudwatch. 

Intro to Collectd networking [here](https://collectd.org/wiki/index.php/Networking_introduction)

## Finding metrics in Cloudwatch

Metrics collected by the Cloudwatch agent will appear in the 'metrics' panel under the CWAgent namespace as <cloudwatch_agent_config/metrics/metrics_collected/collectd/name_prefix>_<collectd_plugin_name>_value e.g. collectd_cpu_value, collectd_wlsadminserver_value, collectd_amazonssmagent_value etc.

Cloudwatch metrics are easily filtered by instance_id so you can see all the metrics for a particular instance.
