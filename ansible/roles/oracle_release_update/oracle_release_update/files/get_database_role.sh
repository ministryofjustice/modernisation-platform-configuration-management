#!/bin/bash
# Determine whether all specified databases are PRIMARY or STANDBY.
# Usage: get_database_role.sh [SID1 SID2 ...]

. ~/.bash_profile

SIDS="${@:-$ORACLE_SID}"
PRIMARY_COUNT=0
STANDBY_COUNT=0
TOTAL_COUNT=0

for SID in $SIDS; do
    if [[ $(grep ^${SID}: /etc/oratab | wc -l) -eq 0 ]]; then
        continue
    fi

    export ORACLE_SID=$SID

    ROLE=$(sqlplus -s / as sysdba <<EOSQL
    SET HEADING OFF FEEDBACK OFF VERIFY OFF PAGESIZE 0
    WHENEVER SQLERROR EXIT FAILURE
    SELECT database_role
    FROM   v\$database;
    EXIT
EOSQL
)

    ROLE=$(echo "$ROLE" | tr -d '[:space:]')

    case "$ROLE" in
        PRIMARY)
            PRIMARY_COUNT=$((PRIMARY_COUNT + 1))
            TOTAL_COUNT=$((TOTAL_COUNT + 1))
            ;;
        *STANDBY*)
            STANDBY_COUNT=$((STANDBY_COUNT + 1))
            TOTAL_COUNT=$((TOTAL_COUNT + 1))
            ;;
        *)
            echo "UNKNOWN"
            exit 1
            ;;
    esac
done

if [[ $TOTAL_COUNT -eq 0 ]]; then
    echo "UNKNOWN"
elif [[ $PRIMARY_COUNT -eq $TOTAL_COUNT ]]; then
    echo "PRIMARY"
elif [[ $STANDBY_COUNT -eq $TOTAL_COUNT ]]; then
    echo "STANDBY"
else
    echo "MIXED"
fi
