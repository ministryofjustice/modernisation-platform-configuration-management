#!/bin/bash
#
#  Get Recent AWS DMS Apply Exceptions
#

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
      PASSWORD=$(aws secretsmanager get-secret-value --secret-id delius-core-${DELIUS_ENVIRONMENT}-oracle-db-dba-passwords --region eu-west-2 --query SecretString --output text 2>/dev/null | jq -r .${USERNAME})
      echo "${PASSWORD}"
    else
      # Try the format used for nomis and oasys
      PASSWORD=$(aws secretsmanager get-secret-value --secret-id "/oracle/database/$2/passwords" --region eu-west-2 --query SecretString --output text 2>/dev/null | jq -r .${USERNAME})
      echo "${PASSWORD}"
    fi
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
if [[ $(srvctl config database -d ${ORACLE_SID} | awk -F: '/Start options/{print $2}' | tr -d ' ') == mount ]];
then
    # Ignore this metric on mounted (not open) databases
    exit 0
fi

# Retrieve DBSNMP password
DBSNMP_PASSWORD=$(get_password dbsnmp $ORACLE_SID)
if [[ -n "$DBSNMP_PASSWORD" && "$DBSNMP_PASSWORD" != "null" ]]; then
  CONNECTION_STRING="dbsnmp/${DBSNMP_PASSWORD}"
else
  CONNECTION_STRING="/ as sysdba"
fi


# Check if the AWS DMS Apply Exceptions Table exists (it will not if this database is not running replication)
table_exists=$(sqlplus -S "$CONNECTION_STRING" <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM dba_tables WHERE owner='DELIUS_AUDIT_DMS_POOL' AND table_name = 'awsdms_apply_exceptions';
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

# First column is total number of errors in past 24 hours
# Second column is total number of errors (to encourage housekeeping of the table)
sqlplus -s "$CONNECTION_STRING" <<EOSQL
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
SET LINES 512
SELECT
COALESCE(
    SUM(
        CASE
            WHEN error_time > sysdate - 1 THEN
                1
            ELSE
                0
        END
    ),0)
    || '|'
    || COUNT(*)
FROM
    delius_audit_dms_pool."awsdms_apply_exceptions";
EXIT
EOSQL