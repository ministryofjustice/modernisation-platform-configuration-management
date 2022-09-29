This module deploys the config for script-exporter which surfaces info about oracle_sids on the host for prometheus to scrape.

It has 2 dependencies:

1. The script-exporter role from the [modernisation-platform-base-ami](https://github.com/ministryofjustice/modernisation-platform-ami-builds/tree/main/ansible/roles/script-exporter) repo has already been run on it.
2. ec2 facts are available from the get-ec2-facts role in this repo.

This role is only required for Rhel7.9 hosts as the nomis_db isn't running on anything else.