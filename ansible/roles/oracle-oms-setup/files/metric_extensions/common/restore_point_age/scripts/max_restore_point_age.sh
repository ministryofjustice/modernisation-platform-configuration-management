#!/bin/bash

. ~/.bash_profile


# Exit without failure if database is not up
srvctl status database -d $ORACLE_SID >/dev/null || exit 0

sqlplus -s / as sysdba <<EOSQL
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
COL max_restore_point_age FORMAT 99990
SELECT COALESCE(MAX(TRUNC(SYSDATE)-TRUNC(TIME)),0) max_restore_point_age
FROM   v\$restore_point;
EXIT
EOSQL
