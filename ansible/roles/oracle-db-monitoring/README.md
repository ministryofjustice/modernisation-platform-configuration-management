This module deploys the config for script-exporter which surfaces info about oracle_sids on the host for prometheus to scrape.

It has 2 dependencies:

1. The script-exporter role from the [modernisation-platform-base-ami](https://github.com/ministryofjustice/modernisation-platform-ami-builds/tree/main/ansible/roles/script-exporter) repo has already been run on it.
2. ec2 facts are available from the get-ec2-facts role in this repo.

This role is only required for Rhel7.9 hosts as the nomis_db isn't running on anything else.

You can check this service is running on the host by running: - 

`service script-exporter status`

Check that metrics are being made available for prometheus to scrape via: -

`curl localhost:9172/metrics`

Check specific script-exporter scripts are working properly via: -

`curl localhost:9172/probe?name=<script_name_in_config.yml>` e.g. oracle_health_check_CNOMT1
