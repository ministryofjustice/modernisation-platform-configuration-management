# Overview

Role for configuring scheduled oracle DB backups, or taking adhoc backups
Status of backups is stored in /opt/textfile_monitoring for monitoring, e.g.
see collectd-textfile-monitoring role.

# Pre-requisite for scheduled backup  

For S3 bucket with recovery catalog, in SSM parameter store save details for 
/database/recovery-catalog-owner/username
/database/recovery-catalog-owner/password 

In group_vars add details for backup schedule and catalog details 
# rman details
rman_backup_script: rman_backup.sh
recovery_catalog: 1
recovery_catalog_server: "{{ OMS_SERVER }}"
rman_backup_cron:
  backup_level_0:
    - name: rman_backup_weekly
      weekday: "0"
      minute: "30"
      hour: "07"
      # job: command generated in rman-backup-setup
  backup_level_1:
    - name: rman_backup_daily
      weekday: "1-6"
      minute: "30"
      hour: "07"
      # job: command generated in rman-backup-setup
  monitoring:
    - name: rman_backup_monitoring
      weekday: "*"
      minute: "30"
      hour: "*"
      job: "su oracle -c '/home/oracle/admin/rman_scripts/{{ rman_backup_monitoring_script }}' | logger -p local3.info -t rman-backup"

Example:
no_proxy="*" ansible-playbook site.yml --limit test-oem-a -e force_role=oracle-db-backup

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
