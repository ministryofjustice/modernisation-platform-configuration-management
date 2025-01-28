#!/bin/bash

. ~/.bash_profile

# Function to identify all ORACLE_SID values on the host
get_oracle_sids() {
  grep -E '^[^+#]' /etc/oratab | awk -F: 'NF && $1 ~ /^[^ ]/ {print $1}'
}

# Function to determine if the TIME column exists in V$RESTORE_POINT as it was only introduced in 12.2
check_time_column() {
  sqlplus -s / as sysdba <<EOF
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
    sqlplus -s / as sysdba <<EOF
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
SELECT SYS_CONTEXT('USERENV', 'DB_NAME') || '|' || 
       TRIM(TO_CHAR(COALESCE(MAX(TRUNC(SYSDATE)-TRUNC(TIME)),0))) AS OUTPUT
FROM V\$RESTORE_POINT;
EXIT;
EOF
  else
    # Fallback to SCN_TO_TIMESTAMP
    sqlplus -s / as sysdba <<EOF
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SELECT SYS_CONTEXT('USERENV', 'DB_NAME') || '|' || 
       TRIM(TO_CHAR(NVL(MAX(SYSDATE - SCN_TO_TIMESTAMP(SCN)), 0))) AS OUTPUT
FROM V\$RESTORE_POINT;
EXIT;
EOF
  fi
}

# Main script execution
sids=$(get_oracle_sids)
if [ -z "$sids" ]; then
  # if no sids on this instance just exit
  exit 0
fi

for sid in $sids; do
  max_age=$(get_max_restore_point_age "$sid")
  # Format output with pipe delimiter
  echo "$max_age"
done

