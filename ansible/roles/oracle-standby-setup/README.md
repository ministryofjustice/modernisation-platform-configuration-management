This role is used for setting new standby database 

## Requirements

1. Primary database config setup step needs to be run.

2. For backup based standby duplication - 
    a. Take Primary database backup to S3 bucket or disk (role to use for backup -  oracle-db-adhoc-backup)
    b. For primary DB disk based backups , make sure its restored in the same directory structure as primary on standby server. 


## Testing


- For Primary database config setup for new standby - 
ansible-playbook site.yml --limit t1-nomis-db-1-a   -e force_role=oracle-standby-setup --tags primary


- To create standby database from S3 backup (without active duplication of database) - 
ansible-playbook  site.yml --limit t1-nomis-db-2-a  -e force_role=oracle-standby-setup --tags standby --extra-vars restore_from="s3_backup"

- To create standby database from disk backup - 
ansible-playbook  site.yml --limit t1-nomis-db-2-a  -e force_role=oracle-standby-setup --tags standby

- To create standby database from active database - 
ansible-playbook  site.yml --limit t1-nomis-db-2-a  -e force_role=oracle-standby-setup --tags standby --extra-vars "active_duplication=Y"

