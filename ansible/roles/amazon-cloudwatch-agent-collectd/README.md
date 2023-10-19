# Role to configure custom cloud watch metrics via collectd

This role adds the additional configuration required for AmazonCloudWatch agent
to read custom metrics from collectd.

## Pre-requisites

The amazon-cloudwatch-agent and collectd roles have been installed

## Custom metrics

Use separate roles for actually adding custom metrics. Role names are prefixed with collectd

## Finding metrics in Cloudwatch

Metrics collected by the Cloudwatch agent will appear in the 'metrics' panel under the CWAgent namespace prefixed with collectd_
Cloudwatch metrics are easily filtered by instance_id so you can see all the metrics for a particular instance.
