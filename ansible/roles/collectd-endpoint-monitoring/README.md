# Role to configure endpoint monitoring via collectd

Monitor the status of endpoints via collectd and cloudwatch.

The role installs a collectd configuration file for using an exec plugin,
and a script for checking the status of an endpoint.

Use this if you cannot use an alternative solution such as pingdom due
to IP allow listing restrictions, and you already have a linux EC2 that
can be used for this kind of monitoring.

Use `collectd-connectivity-tests` role if you just want to check
connectivity to an IP/port.

Why collectd? This is Amazon recommended approach for collecting metrics
from an EC2 via CWAgent

## Finding metrics in Cloudwatch

Metrics collected by the Cloudwatch agent will appear in the 'metrics' panel under the CWAgent namespace

```
metric:        collectd_endpoint_monitoring_status (the metric_name)
type:          exitcode (fixed, 0 = ok, non-zero = error)
type_instance: Friendly name of URL, e.g. c.nomis.service.justice.gov.uk (the metric_dimension)

metric:        collectd_endpoint_monitoring_cert_days_to_expiry (the metric_name)
type:          gauge (number of days until cert expires)
type_instance: Friendly name of URL, e.g. amazonssmagent (the metric_dimension)
```

Cloudwatch metrics are easily filtered by `instance_id` so you can see all the metrics for a particular instance.
