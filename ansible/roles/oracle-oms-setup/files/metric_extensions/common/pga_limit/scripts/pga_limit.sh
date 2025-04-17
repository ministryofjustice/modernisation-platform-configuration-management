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
      PASSWORD=$(aws secretsmanager get-secret-value --secret-id delius-core-${DELIUS_ENVIRONMENT}-oracle-db-dba-passwords --region eu-west-2 --query SecretString --output text 2>/dev/null | jq -r .${USERNAME})
      echo "${PASSWORD}"
    else
      # Try the format used for nomis and oasys
      PASSWORD=$(aws secretsmanager get-secret-value --secret-id "/oracle/database/$2/passwords" --region eu-west-2 --query SecretString --output text 2>/dev/null | jq -r .${USERNAME})
      echo "${PASSWORD}"
    fi
  fi
}

# Function to identify all ORACLE_SID values on the host
get_oracle_sids() {
  grep -E '^[^+#]' /etc/oratab | awk -F: 'NF && $1 ~ /^[^ ]/ {print $1}'
}

run_sql() {
  local ORACLE_SID=$1
  export ORACLE_SID
  export ORAENV_ASK=NO
  . oraenv >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "$ORACLE_SID||"
    return
  fi

  # Exit without failure if database is not up
  srvctl status database -d $ORACLE_SID >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "$ORACLE_SID||"
    return
  fi

  sqlplus -s "$CONNECTION_STRING" <<EOF
SET PAGES 0
SET LINES 40
SET FEEDBACK OFF
SET ECHO OFF
SET HEAD OFF
SELECT
    SYS_CONTEXT('USERENV', 'DB_NAME') || '|' ||
    (SELECT value FROM v\$pgastat WHERE name = 'total PGA allocated') || '|' ||
    CASE
        WHEN EXISTS (
            SELECT 1 FROM v\$parameter
            WHERE name = 'pga_aggregate_limit' AND value IS NOT NULL
        )
        THEN (SELECT value FROM v\$parameter WHERE name = 'pga_aggregate_limit')
        ELSE (SELECT value FROM v\$parameter WHERE name = 'pga_aggregate_target')
    END AS result
FROM dual;
EXIT
EOF
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

  sessions=$(run_sql "$sid")
  # Format output with pipe delimiter
  echo "$sessions"
done

