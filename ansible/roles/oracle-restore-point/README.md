# Overview

Use this role to create database guaranteed restore points 

# Pre-requisites

SYS user database Passwords stored in SSM parameter store. 

# Example

1. Create Restore point 

```
no_proxy="*" ansible-playbook site.yml --limit t1-nomis-db-1-a  -e force_role=oracle-restore-point -e restore_point_name=PRE_ROLE_RUN -e db_tns_list=T1MIS,T1CNMAUD,T1CNOM --tags create_restore_point
```

2. Drop restore point 

```
no_proxy="*" ansible-playbook site.yml --limit t1-nomis-db-1-a  -e force_role=oracle-restore-point -e restore_point_name=PRE_ROLE_RUN -e db_tns_list=T1MIS,T1CNMAUD,T1CNOM --tags drop_restore_point
```
