This role can be used to backup an Oracle database using RMAN to disk or S3 bucket for database standby or active database duplication. 

## Requirements

1. db_name, backup_dir, backup_for and backup_tag parameters needs to be passed to execute this role .

## Testing

For database backup to S3 -  
ansible-playbook site.yml --limit t1-nomis-db-1-a   -e force_role=oracle-db-adhoc-backup --extra-vars "db_name=CNOMPOC backup_for=ha"

For database backup to Disk - 
ansible-playbook site.yml --limit t1-nomis-db-1-a   -e force_role=oracle-db-adhoc-backup --extra-vars "db_name=CNOMPOC backup_for=ha backup_dir=/u02/DB_BKP backup_tag=TEST_BKP"
