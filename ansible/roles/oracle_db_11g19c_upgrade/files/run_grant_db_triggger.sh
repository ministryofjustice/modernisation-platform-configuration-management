#!/bin/bash

# grant ADMINISTER DATABASE TRIGGER privilege

BACKUPDIR="/u02/stage/${ORACLE_SID}/"

cd "$BACKUPDIR" || exit 1

sqlplus -s / as sysdba <<EOSQL

WHENEVER SQLERROR EXIT FAILURE


set pagesize 0;
set echo off;
set verify off;


spool grant_db_trigger_privs.sql

SELECT 'GRANT ADMINISTER DATABASE TRIGGER TO ' || owner || ';'
FROM dba_triggers
WHERE TRIM(base_object_type) = 'DATABASE'
  AND owner NOT IN (
    SELECT grantee
    FROM dba_sys_privs
    WHERE privilege = 'ADMINISTER DATABASE TRIGGER'
  )
GROUP BY owner;

spool off

@grant_db_trigger_privs.sql

EXIT

EOSQL






