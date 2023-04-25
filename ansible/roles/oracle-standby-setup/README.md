This role is used for setting new standby database 

## Requirements

Defaults needs to be setup for this role execution. 

## Testing


For Primary database config setup for new standby - 
ansible-playbook site.yml --limit t1-nomis-db-1-a   -e force_role=oracle-standby-setup --tags primary


