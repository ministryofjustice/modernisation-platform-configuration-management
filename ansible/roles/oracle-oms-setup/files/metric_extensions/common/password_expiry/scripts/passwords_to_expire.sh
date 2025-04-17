#!/bin/bash

. ~/.bash_profile

# Function to retrieve passwords from AWS Secrets Manager
get_password() {
  USERNAME=$1
  if [[ "${ORACLE_SID}" == "EMREP" || "${ORACLE_SID}" == *RCVCAT* ]]; then
    aws secretsmanager get-secret-value --secret-id "/oracle/database/EMREP/passwords" --region eu-west-2 --query SecretString --output text | jq -r .${USERNAME}
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
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
COL user FORMAT A40
SELECT SYS_CONTEXT('USERENV', 'DB_NAME') || '|' || 
  username||'|'||TO_NUMBER(TRUNC(expiry_date)-TRUNC(SYSDATE))
FROM   dba_users
WHERE  account_status = 'OPEN'
AND    expiry_date IS NOT NULL
AND    SIGN(TRUNC(expiry_date)-TRUNC(SYSDATE)) = 1;
EXIT
EOF
}


# Main script execution
sids=$(get_oracle_sids)
if [ -z "$sids" ]; then
  # if no sids on this instance just exit
  exit 0
fi

for sid in $sids; do
  # Retrieve DBSNMP password
  DBSNMP_PASSWORD=$(get_password dbsnmp $sid)
  if [[ -n "$DBSNMP_PASSWORD" && "$DBSNMP_PASSWORD" != "null" ]]; then
    CONNECTION_STRING="dbsnmp/${DBSNMP_PASSWORD}"
  else
    CONNECTION_STRING="/ as sysdba"
  fi

  sessions=$(run_sql "$sid")
  # Format output with pipe delimiter
  echo "$sessions"
done

