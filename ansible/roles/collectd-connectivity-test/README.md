Check connectivity with a remote host/port using netcat.

Define a `collectd-connectivity-tests` tag on the AWS instance. In format "hostname1:port1 hostname2:port2 ...".
A collectd_connectivity_test.sh script is spawned to periodically check each hostname:port using netcat.

The hostname:port will be used as a dimension in cloudwatch:

Metric                                type     type_instance
collectd_connectivity_test_value      exitcode hostname1:port1
collectd_connectivity_test_value      exitcode hostname2:port2

The metric value is the netcat exitcode, i.e. 0 if connected, non-zero if not.
