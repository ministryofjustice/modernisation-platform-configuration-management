# Overview

Role for configuring scheduled oracle DB backups, or taking adhoc backups

## Scheduled Oracle DB Backups

Enabled by defining `rman_backup_script` variable, e.g. in `group_vars`.
A default cron schedule is provided but this can also be changed via `group_vars`.

TODO: enable cloudwatch/collectd monitoring of the backups.

## Adhoc DB Backups

When standing up a new DB instance in standby mode via `oracle-db-standby-setup`
role, use this role to take an adhoc backup including a copy of the password
file. By default the role will backup to disk, upload to S3, and then cleanup
the disk backup.

You could backup directly to S3, but backing up to disk is consistent with the
approach taken with Azure DBs.  Advantage is the restore code is the same
regardless of whether the backup was taken in Azure or AWS.

Example

```
# recommended approach (take note of the backup label in debug output)
ansible-playbook site.yml --limit t1-nomis-db-1-b -e force_role=oracle-db-backup -e db_name=TRDATT1 --tags rman-adhoc-backup

# force a particular backup label
ansible-playbook site.yml --limit t1-nomis-db-1-b -e force_role=oracle-db-backup -e db_name=T1CNOMS1 -e adhoc_backup_label=20230615T160631 --tags rman-adhoc-backup

# just run the AWS upload component
ansible-playbook site.yml --limit t1-nomis-db-1-b -e force_role=oracle-db-backup -e db_name=T1CNOMS1 -e adhoc_backup_label=20230615T160631 -e rman_adhoc_backup_control="s3"  --tags rman-adhoc-backup
```
