#!/bin/bash
#
#  Calculate the time since the oldest materialized refresh (in minutes)
#

. ~/.bash_profile

# Exit without failure if database is not up
srvctl status database -d $ORACLE_SID >/dev/null || exit 0

# Exit without failure if the database is mounted and not open (probably a standby database)
(srvctl status database -d $ORACLE_SID -v | grep -q Mounted) && exit 0

sqlplus -s / as sysdba <<EOSQL
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
COL time_since_oldest_mv_refresh FORMAT 99990
SELECT COALESCE((SYSDATE-MIN(last_refresh_end_time))*24*60,0) time_since_oldest_mv_refresh
FROM   dba_mviews;
EXIT
EOSQL
