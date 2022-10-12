This role can be used to restore an Oracle database from an RMAN backup located in an s3 bucket. 

Requirements: 

1. The s3 folder holding the bucket must be named <databasename>_YYYYMMDD
2. This must be defined as `s3-db-restore-dir` tag in the ec2 database instance that's being created in `modernisation-platform-environments`
    - e.g. s3-db-restore-dir = "CNOMT1_20211214"
3. The s3 bucket must be in the same region as the database instance
    - not _necessarily_ the same account
    - SSE-S3 encryption key must be used for the objects in the folder
        - this can be changed manually via the AWS console
