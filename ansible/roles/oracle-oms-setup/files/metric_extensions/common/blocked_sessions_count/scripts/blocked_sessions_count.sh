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

get_blocked_sessions_count() {
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

  # Exit without failure if the database is mounted and not open (probably a standby database)
  (srvctl status database -d $ORACLE_SID -v | grep -q Mounted) && exit 0


  sqlplus -s "$CONNECTION_STRING" <<EOF
SET PAGES 0
SET LINES 40
SET FEEDBACK OFF
SET ECHO OFF
WITH blocking_session AS
(SELECT s.sid,
        s.serial#,
        l.id1,
        l.id2
 FROM  v\$lock l
 INNER JOIN v\$session s ON l.sid = s.sid
 AND l.block = 1
 AND s.type != 'BACKGROUND'),
 waiting_session AS
(SELECT s.sid,
        l.id1,
        l.id2
 FROM  v\$lock  l
 INNER JOIN v\$session s ON l.sid = s.sid
 AND l.request <> 0
 AND NOT (s.event = 'enq: CI - contention' AND s.p1 LIKE '112%' and s.program like 'rman@%' ) -- Ignore Cross Instance Call Waits for ASM Map Locks during RMAN Backup
 AND s.type != 'BACKGROUND')
SELECT b.sid||'|'||b.serial#||'|'||count(*)
FROM blocking_session b,
     waiting_session w
WHERE w.id1 = b.id1
AND w.id2 = b.id2
AND w.sid <> b.sid
AND NOT EXISTS (SELECT 1 
                 FROM   dba_objects o
                 WHERE  w.id1 = o.object_id 
                 AND (o.owner,o.object_name) IN (('NDMIS_DATA','AUDITED_INTERACTION'))
                 )
GROUP BY b.sid,b.serial#;
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

  sessions=$(get_blocked_sessions_count "$sid")
  # Format output with pipe delimiter
  echo "$sessions"
done


