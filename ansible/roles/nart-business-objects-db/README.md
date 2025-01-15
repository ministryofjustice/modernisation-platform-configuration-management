# nart-business-objects-db ansible role

## Introduction

Use this role to create NART business objects system and audit DBs with corresponding users.
For both Nomis Combined Reporting and ONR
Role is renamed from ncr-db

## Pre-Requisites

- Ansible group vars correctly defined
- Secrets are configured in AWS

### Ansible

Please define following in relevant `group_vars/` yaml:

- `system_db_sid`
- `audit_db_sid`
- `audit_service_name`
- `system_service_name`

### Secret `/oracle/database/{{ system_db_sid }}/passwords`

This will auto-generate passwords for following. Or you can pre-define them:

- `sys`
- `system`
- `dbsnmp`
- `bip_system_owner`
- `bods_ips_system_owner`
- `bods_repo_owner`

### Secret `/oracle/database/{{ audit_db_sid }}/passwords`

This will auto-generate passwords for following. Or you can pre-define them:

- `sys`
- `system`
- `dbsnmp`
- `bip_audit_owner`
- `bods_ips_audit_owner`

## Example usage:

```
ansible-playbook site.yml --limit t2-oasys-db-a -e force_role=nart-business-objects-db
```
