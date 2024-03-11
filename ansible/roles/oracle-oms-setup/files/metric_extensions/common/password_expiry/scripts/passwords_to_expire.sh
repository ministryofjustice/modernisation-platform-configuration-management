#!/bin/bash

. ~/.bash_profile


# Exit without failure if database is not up
srvctl status database -d $ORACLE_SID >/dev/null || exit 0

sqlplus -s / as sysdba <<EOF
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
COL user FORMAT A40
SELECT username||'|'||TO_NUMBER(TRUNC(expiry_date)-TRUNC(SYSDATE))
FROM   dba_users
WHERE  account_status = 'OPEN'
AND    expiry_date IS NOT NULL
AND    SIGN(TRUNC(expiry_date)-TRUNC(SYSDATE)) = 1;
EXIT
EOF
