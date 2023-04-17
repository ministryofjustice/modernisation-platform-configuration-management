This role can be used to restore an Oracle database from an RMAN backup located in an s3 bucket. 

## Requirements

1. The s3 folder holding the bucket must be named <databasename>_YYYYMMDD
2. This must be defined as `s3-db-restore-dir` tag in the ec2 database instance that's being created in `modernisation-platform-environments`
    - e.g. s3-db-restore-dir = "CNOMT1_20211214"
3. The s3 bucket must be in the same region as the database instance (e.g. eu-west-2)
    - not _necessarily_ the same account
    - SSE-S3 encryption key must be used for the objects in the folder
        - this can be changed manually via the AWS console

## Testing

There's several means of testing this when logged onto the EC2 instance using SSM

`sudo less /var/log/messages | grep user-data`
    - this will show the output of running this role

```
sudo su - oracle
. oraenv
+ASM
crsctl stat res -t
```
    - this will show the status of the database
    - you should see ora.cnomt1.db as 1, ONLINE, ONLINE, <instancename>, Open

