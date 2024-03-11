#!/bin/bash

. ~/.bash_profile

# Exit without failure if database is not up
srvctl status database -d $ORACLE_SID >/dev/null || exit 0

sqlplus -s / as sysdba <<EOSQL
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
COL max_audited_interaction_age FORMAT 99990
SELECT non_prod_source ||'|'|| COALESCE(MAX(TRUNC(SYSDATE)-TRUNC(date_time)),0) 
FROM   delius_audit_schema.repo_audited_interaction
GROUP BY non_prod_source;
EXIT
EOSQL
