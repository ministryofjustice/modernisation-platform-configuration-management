# Overview

Role to set up trigger file for mis load and status monitoring

## Mis Load Trigger

The trigger_mis_load.sh script is intended to be triggered by the Oracle db on the instance. This role is intended to check connectivity before creating the trigger file.

There is a connection check step to ensure the target instance is up and running before the playbook is run.

This role uses pywinrm to connect to Windows hosts and execute commands on them. It will execute where the EC2 instance has a tag of 'misload_target'. This needs to be the FQDN of the target instance.

Ntlm authentication is used and the username/passwords for the target instance are fetched from the AWS parameter store. The parameter stores are being created in the various nomis environment locals and locals_database.tf in the modernisation-platform-environments repo. Parameter values are being put in the stores manually from the relevant Azure key vaults.

The python scripts fetch the credentials which means they are not stored in the playbook or in the repo.

## Status Monitoring

In order to have a metric output available which is (easily) obtainable from the AWS Cloudwatch /var/log/messages log stream the misload_monitoring.sh script is run as a cron job every hour.

It will print out the log line in this format

`Jul 27 16:30:01 t1-nomis-db-2-a misload: misload-status T1MIS 0 last-triggered: 2023-07-26 23:27:01`

misload-status <dbname> 0 indicates that there is a misload success entry in the db for that day
misload-status <dbname> 1 means misload entry for the current day has failed

last-triggered: is the UTC time that the trigger_mis_load.sh script was ran

NOTE: There are still improvements to be made to this log message associated with the misload-status to take into account the following: 

1. misload has been triggered but there is still no success after 6am
2. misload has not been triggered and there is no successful misload in the last 24 hours

These will be added to the misload_monitoring.sh script logic shortly