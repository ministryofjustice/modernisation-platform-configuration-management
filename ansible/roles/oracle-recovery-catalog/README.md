# Overview

Use this role when configuring a new recovery catalog database. 


# Known Issues


# Pre-requisites

Ensure `db_config` variable is configured with all recovery catalog database settings.

This is typically defined within `group_vars`.  For example:

```
db_configs:
  RCVCAT:
    rcvcat_db_name: TRCVCAT
    rcvcat_user_name: rcvcatowner
```

# Example

1. Setup recovery catalog database for backups. 

```
ansible-playbook site.yml --limit i-0d8cde27a11a74197  -e force_role=oracle-recovery-catalog -e rcvcat=RCVCAT

```
