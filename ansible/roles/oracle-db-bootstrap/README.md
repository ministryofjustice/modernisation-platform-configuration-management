hmpps-delius-core-oracledb-bootstrap
=========

Role to bootstrap our oracledb amis, run the asm configuration and then create the db schema


Role Variables
--------------

```yaml
    - service_user_name             # defaults to oracle
    - database_global_database_name # db name we are creating defaults to TEST
    - database_sid                  # sid of db defaults to TEST
    - database_type                 # whether it's a primary or standby, defaults to STANDALONE
    - database_characterset         # defaults to AL32UTF8
    - asm_disks_quantity            # Number of EBS volumes attached for ASM Disks

    # the following are required if the db is not a database_type: standby
    - dependencies_bucket_arn       # Arn of the bucket where the db backups are stored
    - database_bootstrap_restore    # Whether this environement has restore on bootsrap. defaults to False
    - database_backup               # S3 backup prefix (path)
    - database_backup_sys_passwd    # Name of SSM parameter
    - database_backup_location      # path on instance where back is to be restored from


```

Example Playbook
----------------

Including an example of how to use your role (for instance, with variables passed in as parameters) is always nice for users too:

    - hosts: localhost
      vars_files:
        - /path/to/vars.yml
      roles:
         - { role: hmpps-delius-core-oracledb-bootstrap }

License
-------

MIT
