# Overview

Use this role when configuring a new standby database.

1. First setup the primary database to support the new standby database 
2. Take adhoc backup of primary database (using oracle-db-backup role in this repo, or rman-backup role in ansible-monorepo)
3. Setup standby database

# Known Issues

The primary database log archive breaks if you change the IP of the standby
server. This shouldn't happen in normal operation, but if you are repeatedly
spinning up new standby servers to test the ansible code, you may run into
it.  To fix the issue, log onto the primary database and update the standby
TNS entry to use IP address. Do a few archive switches and then change the
TNS back to the hostname.This should fix the issue.

# Example

1. Setup primary database to support the new standby database

```
# azure example (ansible-monorepo)
ansible-playbook playbooks/oracle-db-standby-setup.yml -i inventory/inventory-devtest.yml -k -e target_host=T1PDL0009 -e db_primary_name=TRDATT1 -e db_standby_name=T1TRDS1

# aws example (this repo)
ansible-playbook site.yml --limit t1-nomis-db-1-a -e force_role=oracle-db-standby-setup -e db_primary_name=TRDATT1 -e db_standby_name=T1TRDS1 --tags oracle-db-standby-setup-on-primary
```

2. Take adhoc backup of primary database

```
# azure example (ansible-monorepo)
ansible-playbook playbooks/rman-backup.yml -i inventory/inventory-devtest.yml -k -e target_host=T1PDL0009 -e db_name=TRDATT1 --tags rman-adhoc-backup
```

3. Setup standby database

```
ansible-playbook site.yml --limit t1-nomis-db-1-b -e force_role=oracle-db-standby-setup -e db_primary_name=TRDATT1 -e db_standby_name=T1TRDS1 -e adhoc_backup_label=20230511T113235 --tags oracle-db-standby-setup-from-disk-backup
```
