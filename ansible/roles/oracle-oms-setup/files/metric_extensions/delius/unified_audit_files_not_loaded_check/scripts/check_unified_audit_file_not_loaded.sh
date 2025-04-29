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

# Function to identify all ORACLE_SID values on the host
get_oracle_sids() {
  grep -E '^[^+#]' /etc/oratab | awk -F: 'NF && $1 ~ /^[^ ]/ {print $1}'
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

check_file_unified_record_not_loaded () {

  local ORACLE_SID=$1
  # Find maximum access time of the unified audit spillover files in format YYYY-MM-DD HH24:MI:SS
  MAX_ACCESS_TIME=$(sudo find /u01/app/oracle/audit/${ORACLE_SID} -type f -printf "%TY-%Tm-%Td %TT\n" | sort -rk1,2 | head -n 1 | cut -f1 | cut -d'.' -f1)

  export ORACLE_SID
  export ORAENV_ASK=NO
  . oraenv >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "$ORACLE_SID|"
    return
  fi

  # Exit without failure if database is not up
  srvctl status database -d $ORACLE_SID >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "$ORACLE_SID|"
    return
  fi
  sqlplus -s "$CONNECTION_STRING" <<EOF
    SET ECHO OFF
    SET FEEDBACK OFF
    SET HEAD OFF
    SET PAGES 0
    WITH max_file_event_timestamp AS
    (
    SELECT MAX(event_timestamp) max_event_timestamp
    FROM unified_audit_trail
    WHERE source ='FILE'
    ),
    check_older_than_one_day AS
    (
    SELECT COUNT(*) count
    FROM max_file_event_timestamp
    WHERE EXTRACT(DAY FROM TO_TIMESTAMP('${MAX_ACCESS_TIME}','YYYY-MM-DD HH24:MI:SS') -  max_event_timestamp) >= 1
    )
    SELECT db_unique_name||'|'||TO_CHAR(max_event_timestamp,'YYYY-MM-DD HH24:MI:SS')||'|'||'${MAX_ACCESS_TIME}'||'|'||count
    FROM check_older_than_one_day
    CROSS JOIN max_file_event_timestamp
    CROSS JOIN v\$database;
    EXIT;
EOF
}

# Main script execution
sids=$(get_oracle_sids)
if [ -z "$sids" ]; then
  # if no sids on this instance just exit
  exit 0
fi

for sid in $sids; do
  # Get the connection string to use for this database
  get_connection $sid

  COUNT=$(check_file_unified_record_not_loaded "$sid")
  # Format output with pipe delimiter
  echo "${COUNT}"
done