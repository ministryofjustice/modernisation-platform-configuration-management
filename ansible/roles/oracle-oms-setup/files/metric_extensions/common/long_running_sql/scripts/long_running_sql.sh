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

run_sql() {
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

  sqlplus -s "$CONNECTION_STRING" <<EOF
SET PAGES 0
SET LINES 40
SET FEEDBACK OFF
SET ECHO OFF
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
select SYS_CONTEXT('USERENV', 'DB_UNIQUE_NAME') || '|' || 
  NVL(MAX(last_call_et),0) max_last_call_et
from v\$session
where type='USER'
and status='ACTIVE'
and (action != 'PRF_COLL_JOB' OR action IS NULL)
and (NOT program LIKE '%rman@%' OR program IS NULL)
and (NOT program LIKE '%(PR__)' OR program IS NULL)
;
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

  # Check if srvctl is available
  if ! command -v srvctl >/dev/null 2>&1; then
    continue
  fi

  # If the database is mounted and not open (probably a standby database), use / as sysdba
  if (srvctl status database -d $ORACLE_SID -v | grep -q Mounted >/dev/null 2>&1) then
    CONNECTION_STRING="/ as sysdba"
  else
    # Use dbsnmp if the database is not a standby
    DBSNMP_PASSWORD=$(get_password dbsnmp $ORACLE_SID)
    if [[ -n "$DBSNMP_PASSWORD" && "$DBSNMP_PASSWORD" != "null" ]]; then
      CONNECTION_STRING="dbsnmp/${DBSNMP_PASSWORD}"
    else
      CONNECTION_STRING="/ as sysdba"
    fi
  fi

  sessions=$(run_sql "$sid")
  # Format output with pipe delimiter
  echo "$sessions"
done
