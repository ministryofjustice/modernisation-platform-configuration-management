#!/bin/bash
#
# Count number of USER_ entries for the last day where:
# (1) The record was created by Data Maintenance
# (2) The NOTES field is NULL
# (3) It is not a SERVICE account
#
# If the count is non-zero this may have identified an audit stub user which has been replicated to this database
# with a missing Notes column.   (All such users should have Notes populated to state that they are stubs).

. ~/.bash_profile

# Function to retrieve passwords from AWS Secrets Manager
get_password() {
  USERNAME=$1
  if [[ "${ORACLE_SID}" == "EMREP" || "${ORACLE_SID}" == *RCVCAT* ]]; then
    aws secretsmanager get-secret-value --secret-id "/oracle/database/${ORACLE_SID}/passwords" --region eu-west-2 --query SecretString --output text | jq -r .${USERNAME}
  else
    INSTANCEID=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)
    APPLICATION=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCEID}" "Name=key,Values=application" --query "Tags[].Value" --output text)
    if [[ "${APPLICATION}" == "delius" ]]; then
      DELIUS_ENVIRONMENT=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCEID}" "Name=key,Values=delius-environment" --query "Tags[].Value" --output text)
      SECRET_ID="delius-core-${DELIUS_ENVIRONMENT}-oracle-db-dba-passwords"
    elif [ "$APPLICATION" = "delius-mis" ]
    then
      DELIUS_ENVIRONMENT=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCEID}" "Name=key,Values=delius-environment" --query "Tags[].Value" --output text)
      DATABASE_TYPE=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCEID}" "Name=key,Values=database" --query 'Tags[].Value' --output text | cut -d'_' -f1)
      SECRET_ID="delius-mis-${DELIUS_ENVIRONMENT}-oracle-${DATABASE_TYPE}-db-dba-passwords"
    else
      # Try the format used for nomis and oasys
      SECRET_ID="/oracle/database/$2/passwords"
    fi
    PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${SECRET_ID} --region eu-west-2 --query SecretString --output text 2>/dev/null | jq -r .${USERNAME})
    echo "${PASSWORD}"
  fi
}

oratab=/etc/oratab

# Only one database should be running on the Delius host
export ORACLE_SID=$(grep -v '^#' $oratab | grep -v AGENT | grep -v -i listener | grep -v -i asm | cut -d ":" -f1 | awk 'NF' | head -1) 
 
ohome=`cat $oratab | grep $ORACLE_SID | grep -v '^#' | grep -v AGENT | grep -v -i listener | grep -v -i asm | cut -d ":" -f2`;
 
ORACLE_HOME=${ohome}; export ORACLE_HOME;
 
export ORAENV_ASK=NO
. oraenv > /dev/null

# Exit without failure if database is not up
srvctl status database -d $ORACLE_SID >/dev/null || exit 0

# Exit without failure if the database is mounted and not open (probably a standby database)
(srvctl status database -d $ORACLE_SID -v | grep -q Mounted) && exit 0

# Retrieve DBSNMP password
DBSNMP_PASSWORD=$(get_password dbsnmp $ORACLE_SID)
if [[ -n "$DBSNMP_PASSWORD" && "$DBSNMP_PASSWORD" != "null" ]]; then
  CONNECTION_STRING="dbsnmp/${DBSNMP_PASSWORD}"
else
  CONNECTION_STRING="/ as sysdba"
fi


# Check if the AWS DMS Suspend Table exists (it will not if this database is not running replication)
table_exists=$(sqlplus -S "$CONNECTION_STRING" <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM dba_tables WHERE owner='DELIUS_APP_SCHEMA' AND table_name = 'USER_';
EXIT;
EOF
)

# Trim any leading/trailing whitespace.
table_exists=$(echo "$table_exists" | xargs)

# If the count is zero, the table does not exist.  Do not treat this as an error
# as this table will only exist if the database is configured as a DMS client.
if [ "$table_exists" -eq 0 ]; then
    exit 0
fi

$ORACLE_HOME/bin/sqlplus -S "$CONNECTION_STRING" <<EOSQL
SET HEAD OFF
SET FEEDBACK OFF
SET PAGES 0


WITH data_maintenance_user AS (
    SELECT
        user_id
    FROM
        delius_app_schema.user_
    WHERE
        distinguished_name = '[Data Maintenance]'
)
SELECT
    COUNT(*) mssing_notes_count
FROM
    delius_app_schema.user_ u
WHERE
        u.created_datetime > sysdate - 1
    AND u.notes IS NULL
    AND u.created_by_user_id = (
        SELECT
            user_id
        FROM
            data_maintenance_user
    )
    AND u.user_id > (
        SELECT
            MAX(service_user.user_id)
        FROM
            delius_app_schema.user_ service_user
        WHERE
                service_user.surname = 'Service'
            AND service_user.created_by_user_id = (
                SELECT
                    user_id
                FROM
                    data_maintenance_user
            )
    );
EXIT
EOSQL
