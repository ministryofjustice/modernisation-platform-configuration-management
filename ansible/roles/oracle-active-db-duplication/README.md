# Overview

Use this role for duplicating Oracle 19c  database with active database duplication.  


# Known Issues


# Pre-requisites

Ensure `db_config` variable is configured with all database settings. 
Ensure Source database is in archivelog and using password file. 

This is typically defined within `group_vars`.  For example:

```
db_configs:
  T3IWFM:
    db_name: T3IWFM
    db_unique_name: T3IWFM
    instance_name: T3IWFM
    host_name: 10.26.8.53
    port: 1521
    tns_name: T3IWFM
    asm_disk_groups: DATA,FLASH
    service:
      - { name: IWFM_TAF, role: PRIMARY }
```

# Example

1. Create duplicate database with active database duplication. 

```

# aws example (this repo)
ansible-playbook site.yml --limit  t3-csr-db-a -e force_role=oracle-active-db-duplication  -e target_db_name=T3IWFM  -e source_db_name=IWFMT3 -e source_host=10.101.69.133

```
