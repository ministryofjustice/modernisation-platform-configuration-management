# Overview

Use this role to create new databases for NART reporting and adds users. Used both for nomis and oasys. 

# Pre-requisites

All database Passwords are stored in SecretsManager. Secrets are stored in /oracle/database/{{ db_sid }}/passwords"
For NOMIS BISYS database passwords for below users need to be saved in aws secrets 
    - sys
    - system
    - bip_system_owner
    - bods_ips_system_owne
    - bods_repo_owner
    - dbsnmp (This will be used for OEM)

For NOMIS BIAUD database passwords for below users need to be saved in aws secrets 
    - sys
    - system
    - bip_audit_owner 
    - bods_ips_audit_owner
    - dbsnmp (This will be used for OEM)

# Example

To create database and users - 

```
no_proxy="*" ansible-playbook site.yml --limit $limit_db -e force_role=ncr-db"
```