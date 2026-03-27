#!/bin/bash
#
# Script to check if the configured automatic expiry of current objects in the S3 Bucket
# used for database backups is sufficiently further into the future than the configured
# retention policy used by RMAN.  This is to ensure that RMAN should be solely responsible
# for deleting obsolete backups from S3 - they should not just be aging out by the
# lifecycle policy of the bucket.

. ~/.bash_profile

BACKUP_BUCKET=$(grep OSB_WS_BUCKET $ORACLE_HOME/dbs/osbws.ora | awk -F= '{print $2}')

AWS_EXPIRATION_DAYS=$(aws s3api get-bucket-lifecycle-configuration --bucket "${BACKUP_BUCKET}" 2>/dev/null \
       | jq -r '
           .Rules // []
           | map(select(.Status=="Enabled"))
           | map(select(.Expiration.Days != null))
           | first
           | .Expiration.Days // "NA"
       ')

RMAN_RETENTION_DAYS=$(echo "show retention policy;" | rman target / | grep "CONFIGURE RETENTION POLICY" | awk '{print $8}')

echo "${BACKUP_BUCKET}|${AWS_EXPIRATION_DAYS}|${RMAN_RETENTION_DAYS}"