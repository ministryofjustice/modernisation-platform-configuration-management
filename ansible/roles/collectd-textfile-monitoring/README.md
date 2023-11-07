# Role to import collectd metrics from textfile via collectd

This is similar to prometheus solution where values are imported from a text file
populated by another process.  By default, the same directory is used

```
/opt/textfile_monitoring/
```

This role does not create the directory, it is assumed another role
will create this with the correct permissions. It needs to be readable by
`ec2-user`.

Files should contain a field and a value, e.g.

```
$ cat /opt/textfile_monitoring/nomis_batch_monitoring.prom

nomis_batch_failure_status 0
```

This will create 2 metrics

```
Metric                                type     type_instance
collectd_textfile_monitoring_seconds  duration nomis_batch_failure_status
collectd_textfile_monitoring_value    gauge    nomis_batch_failure_status
```

The `seconds` metric is the number of seconds since the file was last modified.
