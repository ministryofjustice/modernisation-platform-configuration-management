# Overview

Use this role to setup oasys-sns on oasys database server 

# Pre-requisites

Ensure OASYS database is on database server 


# Example

1. Setup oasys-sns on database server 

```
no_proxy="*" ansible-playbook site.yml --limit t1-oasys-db-a  -e force_role=oracle-sns
```
