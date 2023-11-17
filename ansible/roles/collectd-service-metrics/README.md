# Role to configure monitoring for service state using collectd

Monitor the status of services via collectd and cloudwatch.

The role installs a collectd configuration file for using an exec plugin,
and a script for polling the status of the services.

Two variables are used to define which services are monitored:

- `collectd_monitored_services_role` for services common to all servers
- `collectd_monitored_services_servertype` for services specific to the given server type.

The idea is the `collectd_monitored_services_servertype` is defined in a server
type group vars.

Example configuration is

```
collectd_monitored_services_role:
  - metric_name: service_status_os
    metric_dimension: amazon-ssm-agent
    shell_cmd: "(status amazon-ssm-agent|grep running) || (systemctl is-active amazon-ssm-agent)"
```

The metric name, dimension and command to retrieve the status must all be defined.

Typically we segregate OS level and application level monitoring into different metric
names as different teams maybe responsible for these, e.g. `service_status_os` and
`service_status_app`

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
type_instance: iName of service, e.g. amazonssmagent (the metric_dimension)
```

Cloudwatch metrics are easily filtered by instance_id so you can see all the metrics for a particular instance.
