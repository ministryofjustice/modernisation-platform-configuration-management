# Role to configure monitoring for metrics using collectd

Monitor metrics via collectd and cloudwatch.

The role installs a collectd configuration file for using an exec plugin,
and a script for polling the status of the services.

Two variables are used to define which services are monitored:

- `collectd_monitored_metrics_default` for metrics common to all servers
- `collectd_monitored_metrics_additional` for metrics specific to the given server type.

Example configuration is

```
collectd_monitored_metrics_additional:
  - metric_name: disk_used_percent
    metric_dimension: inode_used_percent_max
    shell_cmd: "df --output=ipcent | tail -n+2 | sed 's/%//' | sort -n | tail -n1 | xargs"
```

The metric name, dimension and command must all be defined.

### Debugging

Most issues with collectd end up in /var/log/messages, including where selinux is blocking collectd from running the script.

Definitely add `debug: true` to the cloudwatch agent config file to see what's going on. It may also be worth sending all the values to a custom namespace to help identify what you're looking at versus the default CWAgent namespace!

Unless you specify otherwise cloudwatch agent logs go to `/opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log` which is also worth checking to make sure the messages it's trying to pick up from the collectd port are making sense.

Collectd relies on plugins, the most important one related to Cloudwatch is the 'network' plugin which posts the metrics data to a UDP endpoint. Cloudwatch picks metrics up from there and sends them on to cloudwatch.

Intro to Collectd networking [here](https://collectd.org/wiki/index.php/Networking_introduction)

## Finding metrics in Cloudwatch

Metrics collected by the Cloudwatch agent will appear in the 'metrics' panel under the CWAgent namespace

```
metric:        collectd_service_status_value  (the metric_name)
type:          exitcode (fixed, 0 = ok, non-zero = error)
type_instance: Name of service, e.g. amazonssmagent (the metric_dimension)
```

Cloudwatch metrics are easily filtered by instance_id so you can see all the metrics for a particular instance.
