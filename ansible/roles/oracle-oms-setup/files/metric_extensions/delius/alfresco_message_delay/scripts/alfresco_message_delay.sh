#!/bin/bash
#
# Calculate the maximum number of minutes an alfresco
# message has been waiting to be processed.
#
# 0: Initial State, Awaiting Processing (Allow 60 mins in this state)
# 4: Picked for Processing (Allow 5 mins in this state)

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

get_connection() {
  local ORACLE_SID=$1
  export ORACLE_SID
  export ORAENV_ASK=NO
  . oraenv >/dev/null 2>&1

  # Test connection with current CONNECTION_STRING
  srvctl config database -d $ORACLE_SID | grep PRIMARY >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    # If not a primary then it must be a standby, so use
    CONNECTION_STRING="/ as sysdba"
  else
    # If a primary then retrieve DBSNMP password
    DBSNMP_PASSWORD=$(get_password dbsnmp $sid)
    if [[ -n "$DBSNMP_PASSWORD" && "$DBSNMP_PASSWORD" != "null" ]]; then
      CONNECTION_STRING="dbsnmp/${DBSNMP_PASSWORD}"
    else
      CONNECTION_STRING="/ as sysdba"
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
srvctl status database -d $ORACLE_SID >/dev/null || exit 0

# Exit without failure if the database is not the primary
(srvctl config database -d $ORACLE_SID | grep -q PRIMARY) && exit 0

# Get the connection string to use for this database
get_connection $ORACLE_SID

# Check if the table exists (it will not if this database is not running replication)
table_exists=$(sqlplus -S "$CONNECTION_STRING" <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM dba_tables WHERE owner='DELIUS_APP_SCHEMA' AND table_name = 'SPG_NOTIFICATION';
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
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
SELECT   processed_flag||'|'||ROUND(COALESCE(MAX(SYSDATE-date_created),0)*24*60,1) mins_in_state
FROM     delius_app_schema.spg_notification
WHERE    processed_flag IN (0,4)
GROUP BY processed_flag;
EXIT
EOSQL
