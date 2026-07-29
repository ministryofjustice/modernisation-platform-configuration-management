#!/bin/bash

BACKUPDIR="/u02/stage/${ORACLE_SID}/acl_backup"

cd "$BACKUPDIR" || exit 1

sqlplus -s / as sysdba <<EOSQL
# SPOOL ${BACKUPDIR}/backup_acls.out
@${BACKUPDIR}/backup_acls.sql
SPOOL OFF
EXIT
EOSQL


