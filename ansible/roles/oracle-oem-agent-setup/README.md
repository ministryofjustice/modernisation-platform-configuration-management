# Overview

Use this role to install Oracle Enterprise Manager Cloud Control 13c Release 5 Installation, Configuration 

# Pre-requisites

Oracle 19c install role already executed successfully on server. oracle-19c role will install Oracle 19c Grid infrstructure, database and create ASM diskgroups needed for oracle-oem-setup role. 


# Example

1. Install Oracle Enterprise Manager Cloud Control 13c Release 5

```
 no_proxy="*" ansible-playbook site.yml --limit i-095a6de86346924dd  -e force_role=oracle-oem-setup
```