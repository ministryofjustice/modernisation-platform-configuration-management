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
      PASSWORD=$(aws secretsmanager get-secret-value --secret-id delius-core-${DELIUS_ENVIRONMENT}-oracle-db-dba-passwords --region eu-west-2 --query SecretString --output text 2>/dev/null | jq -r .${USERNAME})
      echo "${PASSWORD}"
    else
      # Try the format used for nomis and oasys
      PASSWORD=$(aws secretsmanager get-secret-value --secret-id "/oracle/database/$2/passwords" --region eu-west-2 --query SecretString --output text 2>/dev/null | jq -r .${USERNAME})
      echo "${PASSWORD}"
    fi
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

# Exit without failure if the database is mounted and not open (probably a standby database)
(srvctl status database -d $ORACLE_SID -v | grep -q Mounted) && exit 0

# Get the connection string to use for this database
get_connection $ORACLE_SID

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
