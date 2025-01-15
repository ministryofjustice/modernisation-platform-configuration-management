# nart-business-objects-db ansible role

## Introduction

Use this role to create NART business objects system and audit DBs with corresponding users.
For both Nomis Combined Reporting and ONR
Role is renamed from ncr-db

## Pre-Requisites

- Secrets are configured in AWS
- Ansible group vars correctly defined

## Example usage:

```
ansible-playbook site.yml --limit t2-oasys-db-a -e force_role=nart-business-objects-db
```
