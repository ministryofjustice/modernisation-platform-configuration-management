#!/bin/bash

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

# Exit without failure if database is not the primary
srvctl config database -d $ORACLE_SID | grep PRIMARY >/dev/null 2>&1
if [ $? -ne 0 ]; then
  exit 0
fi

# Retrieve DBSNMP password
DBSNMP_PASSWORD=$(get_password dbsnmp $ORACLE_SID)
if [[ -n "$DBSNMP_PASSWORD" && "$DBSNMP_PASSWORD" != "null" ]]; then
  CONNECTION_STRING="dbsnmp/${DBSNMP_PASSWORD}"
else
  CONNECTION_STRING="/ as sysdba"
fi

# Check if the table exists (it will not if this database is not running replication)
table_exists=$(sqlplus -S "$CONNECTION_STRING" <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM DBA_TABLES WHERE OWNER='DELIUS_AUDIT_DMS_POOL' AND TABLE_NAME = 'AUDITED_INTERACTION_CHECKSUM';
EXIT;
EOF
)

# Trim any leading/trailing whitespace.
table_exists=$(echo "$table_exists" | xargs)

# If the count is zero, the table does not exist.  Do not treat this as an error
# as it may be intentional.
if [ "$table_exists" -eq 0 ]; then
    exit 0
fi

$ORACLE_HOME/bin/sqlplus -S "$CONNECTION_STRING" <<EOSQL
SET HEADING OFF
SET PAGES 0
SET FEEDBACK OFF
SET LINES 256

ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';

WITH most_recent_resetlogs AS (
    SELECT
        client_db,
        MAX(start_date_time) resetlogs_date_time
    FROM
        delius_audit_dms_pool.audited_interaction_checksum
    WHERE
        resetlogs = 'Y'
    GROUP BY
        client_db
), most_recently_validated_ranges AS (
    SELECT
        x.client_db,
        x.start_date_time,
        x.end_date_time,
        x.row_count,
        x.data_checksum,
        x.checksum_validated
    FROM
        delius_audit_dms_pool.audited_interaction_checksum x
    WHERE
        ( x.client_db, x.end_date_time ) IN (
            SELECT
                y.client_db, MAX(y.end_date_time)
            FROM
                delius_audit_dms_pool.audited_interaction_checksum y
            WHERE
                y.checksum_validated != 'N'
            AND
                y.start_date_time >= (
                    SELECT
                        resetlogs_date_time
                    FROM
                        most_recent_resetlogs r
                    WHERE
                        r.client_db = y.client_db
                )
            GROUP BY
                y.client_db
        )
), monitoring_discontinuities AS (
    SELECT
        a.client_db,
        COUNT(*) discontinuities
    FROM
        delius_audit_dms_pool.audited_interaction_checksum a
    WHERE
        NOT EXISTS (
            SELECT
                1
            FROM
                delius_audit_dms_pool.audited_interaction_checksum b
            WHERE
                    a.client_db = b.client_db
                AND a.end_date_time = b.start_date_time
        )
            AND ( a.client_db, a.start_date_time ) NOT IN (
            SELECT
                c.client_db, MAX(c.start_date_time)
            FROM
                delius_audit_dms_pool.audited_interaction_checksum c
            GROUP BY
                c.client_db
        )
            AND a.start_date_time >= (
            SELECT
                resetlogs_date_time
            FROM
                most_recent_resetlogs r
            WHERE
                r.client_db = a.client_db
        )
    GROUP BY
        a.client_db
)
SELECT
    mrr.client_db
    || '|'
    || rl.resetlogs_date_time
    || '|'
    || mrr.start_date_time
    || '|'
    || mrr.end_date_time
    || '|'
    || round(sysdate - mrr.start_date_time, 1)
    || '|'
    || round(sysdate - mrr.end_date_time, 1)
    || '|'
    || mrr.row_count
    || '|'
    || mrr.data_checksum
    || '|'
    || mrr.checksum_validated
    || '|'
    || coalesce(md.discontinuities, 0)
FROM
         most_recently_validated_ranges mrr
    INNER JOIN most_recent_resetlogs                 rl ON mrr.client_db = rl.client_db
    LEFT OUTER JOIN monitoring_discontinuities            md ON mrr.client_db = md.client_db
GROUP BY
    mrr.client_db,
    rl.resetlogs_date_time,
    mrr.start_date_time,
    mrr.end_date_time,
    mrr.row_count,
    mrr.data_checksum,
    mrr.checksum_validated,
    md.discontinuities;


EXIT
EOSQL
