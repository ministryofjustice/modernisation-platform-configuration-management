#!/bin/bash
# Check the Count of Any Restore Points across all specified databases (or $ORACLE_SID if none given)

. ~/.bash_profile

SIDS="${@:-$ORACLE_SID}"
TOTAL=0

for SID in $SIDS; do
    if [[ $(grep ^${SID}: /etc/oratab | wc -l) -eq 0 ]]; then
        continue
    fi
    export ORACLE_SID=$SID
    COUNT=$(sqlplus -s / as sysdba <<EOSQL
    SET HEADING OFF
    WHENEVER SQLERROR EXIT FAILURE
    SELECT COUNT(*)
    FROM   v\$restore_point;
    EXIT
EOSQL
)
    TOTAL=$((TOTAL + ${COUNT//[[:space:]]/}))
done

echo $TOTAL
