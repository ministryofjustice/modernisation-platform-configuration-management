#!/bin/bash

# Expire user accounts with 10G format passwords, these need to be reviewed.

BACKUPDIR="/u02/stage/${ORACLE_SID}/"

cd "$BACKUPDIR" || exit 1

sqlplus -s / as sysdba <<EOSQL

WHENEVER SQLERROR EXIT FAILURE

set pagesize 0;
set echo off;
set verify off;

spool expire_10gformat.sql

select 'alter user '||username||' password expire'||';'   from DBA_USERS  
where ( PASSWORD_VERSIONS = '10G ' or PASSWORD_VERSIONS = '10G HTTP ') 
and USERNAME <> 'ANONYMOUS' and account_status = 'OPEN'
/

spool off

# @expire_10gformat.sql

EXIT

EOSQL

