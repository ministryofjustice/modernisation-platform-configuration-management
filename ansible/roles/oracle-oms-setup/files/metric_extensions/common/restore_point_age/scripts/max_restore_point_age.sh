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

# Function to determine if the TIME column exists in V$RESTORE_POINT as it was only introduced in 12.2
check_time_column() {
  sqlplus -s "$CONNECTION_STRING" <<EOF
SET HEADING OFF
SET FEEDBACK OFF
SET PAGESIZE 0
WHENEVER SQLERROR EXIT SQL.SQLCODE
SELECT TIME FROM V\$RESTORE_POINT WHERE ROWNUM = 1;
EXIT;
EOF
if [ $? -ne 0 ]; then
  return 1
else
  return 0
fi
}

# Function to calculate the maximum restore point age for a specific ORACLE_SID
get_max_restore_point_age() {
  local ORACLE_SID=$1
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

  # Check if the TIME column exists as it was only introduced in 12.2
  if check_time_column >/dev/null 2>&1; then
    # Use TIME column
    sqlplus -s "$CONNECTION_STRING" <<EOF
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
SELECT SYS_CONTEXT('USERENV', 'DB_UNIQUE_NAME') || '|' || 
       TRIM(TO_CHAR(COALESCE(MAX(TRUNC(SYSDATE)-TRUNC(TIME)),0))) AS OUTPUT
FROM V\$RESTORE_POINT;
EXIT;
EOF
  else
    # Fallback to SCN_TO_TIMESTAMP
    sqlplus -s "$CONNECTION_STRING" <<EOF
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SELECT SYS_CONTEXT('USERENV', 'DB_UNIQUE_NAME') || '|' || 
       TRIM(TO_CHAR(NVL(MAX(SYSDATE - SCN_TO_TIMESTAMP(SCN)), 0))) AS OUTPUT
FROM V\$RESTORE_POINT;
EXIT;
EOF
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

# Main script execution
sids=$(get_oracle_sids)
if [ -z "$sids" ]; then
  # if no sids on this instance just exit
  exit 0
fi

for sid in $sids; do
  # Get the connection string to use for this database
  get_connection $sid

  max_age=$(get_max_restore_point_age "$sid")
  # Format output with pipe delimiter
  echo "$max_age"
done

