# Overview

Role to set up trigger file for mis load and status monitoring

## Mis Load Trigger

The trigger_mis_load.sh script is intended to be triggered by the Oracle db on the instance. This role is intended to check connectivity before creating the trigger file.

The script returns the exit status of the MIS load trigger after updating monitoring and removing the running marker. A non-zero exit status (for example, when the Python script is missing or the remote batch command fails) causes the Oracle Scheduler executable job to be marked as failed. Writing to standard error alone does not determine the job status.

When the trigger fails, the script sets `ERROR_FLAG='Y'` on `BODIMIS.ETL_LOAD_LOG` records whose `LOAD_START_DATETIME` is today and whose `LOAD_END_DATETIME` is null, then commits the update. If no records match, it logs a warning: the failure may have happened before ETL recorded its start. Database-update errors are reported without replacing the original trigger exit status.

There is a connection check step to ensure the target instance is up and running before the playbook is run.

This role uses pywinrm to connect to Windows hosts and execute commands on them. It will execute where the EC2 instance has a tag of 'misload_target'. This needs to be the FQDN of the target instance.

Ntlm authentication is used and the username/passwords for the target instance are fetched from the AWS parameter store. The parameter stores are being created in the various nomis environment locals and locals_database.tf in the modernisation-platform-environments repo. Parameter values are being put in the stores manually from the relevant Azure key vaults.

The python scripts fetch the credentials which means they are not stored in the playbook or in the repo.

## Status Monitoring

Monitoring is via collectd-textfile-monitoring role. A misload status is added to /opt/textfile_monitoring directory which can be picked up by collectd.

The trigger writes its exit status to `misload_status.prom` (zero indicates trigger success, subject to the database status check). Separately, the GoldenGate `misload_failure_check.sh` script writes `misload_success_status.prom` without a leading blank line. Both metrics use zero for no error. `misload_success` is 1 if any load started today has no `LOAD_END_DATETIME` or its `ERROR_FLAG` is not `N` (including null); otherwise it is 0. Completed, non-error loads therefore report 0, as does a day with no started loads. A successful load does not mask another failed or unfinished load on the same day.
