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

oratab=/etc/oratab

# Only one database per host is needed for checking ASM diskgroup usage
export ORACLE_SID=$(grep -v '^#' $oratab | grep -v AGENT | grep -v -i listener | grep -v -i asm | cut -d ":" -f1 | awk 'NF' | head -1) 
 
ohome=`cat $oratab | grep $ORACLE_SID | grep -v '^#' | grep -v AGENT | grep -v -i listener | grep -v -i asm | cut -d ":" -f2`;
 
ORACLE_HOME=${ohome}; export ORACLE_HOME;

PATH=$ORACLE_HOME/bin:$PATH; export PATH;
 
export ORAENV_ASK=NO
. oraenv > /dev/null

# Do not do the following for now as running it on a nomis 19c instance will fail
# Exit without failure if database is not up
# srvctl status database -d $ORACLE_SID >/dev/null || exit 0

# If the database is mounted and not open (probably a standby database), use / as sysdba
if srvctl status database -d $ORACLE_SID -v | grep -q Mounted; then
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

$ORACLE_HOME/bin/sqlplus -S "$CONNECTION_STRING" <<EOSQL
  set heading off
  set echo off
  set feedback off
  set pages 0
  set lines 128
  select name||'|'||round(total_mb/1024)||'|'||round(free_mb/1024)||'|'||round((total_mb-free_mb)/1024)
  from v\$asm_diskgroup;
  exit
EOSQL
