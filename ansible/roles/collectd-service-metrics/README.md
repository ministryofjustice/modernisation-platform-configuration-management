# Role to configure monitoring for service state using collectd

### Debugging continued!

Definitely add `debug: true` to the cloudwatch agent config file to see what's going on. It may also be worth sending all the values to a custom namespace to help identify what you're looking at versus the default CWAgent namespace! Unless you specify otherwise cloudwatch agent logs go to `/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log`

Collectd relies on plugins, the most important one related to Cloudwatch is the 'network' plugin which posts the metrics data to a UDP endpoint. Cloudwatch picks metrics up from there and sends them on to cloudwatch. 

Intro to Collectd networking [here](https://collectd.org/wiki/index.php/Networking_introduction)

In the linux.json.j2 file the `append_dimensions` section needs to exist at the "global" level as well as the metrics level for these additional dimensions to be added to the metrics. This is not obvious from the documentation.

## Finding metrics in Cloudwatch

Metrics collected by the Cloudwatch agent will appear in the 'metrics' panel as <cloudwatch_agent_config/metrics/metrics_collected/collectd/name_prefix>_<collectd_plugin_name>_value e.g. collectd_cpu_value, collectd_exec_value.

Cloudwatch metrics are easily filtered by instance_id so you can see all the metrics for a particular instance.
