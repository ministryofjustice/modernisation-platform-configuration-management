# Overview

Role to set up trigger file for mis load and status monitoring

## Mis Load Trigger

The trigger_mis_load.sh script is intended to be triggered by the Oracle db on the instance. This role is intended to check connectivity before creating the trigger file.

There is a connection check step to ensure the target instance is up and running before the playbook is run.

This role uses pywinrm to connect to Windows hosts and execute commands on them. It will execute where the EC2 instance has a tag of 'misload_target'. This needs to be the FQDN of the target instance.

Ntlm authentication is used and the username/passwords for the target instance are fetched from the AWS parameter store. The parameter stores are being created in the various nomis environment locals and locals_database.tf in the modernisation-platform-environments repo. Parameter values are being put in the stores manually from the relevant Azure key vaults.

The python scripts fetch the credentials which means they are not stored in the playbook or in the repo.

## Status Monitoring

Monitoring is via collectd-textfile-monitoring role. A misload status is added to /opt/textfile_monitoring directory which can be picked up by collectd.
