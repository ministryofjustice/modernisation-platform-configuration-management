#!/bin/bash
# Start one or more databases in UPGRADE mode. Pass SIDs as arguments (defaults to $ORACLE_SID).

. ~/.bash_profile

for SID in "${@:-$ORACLE_SID}"; do
    export ORACLE_SID=$SID
    sqlplus -s / as sysdba <<EOF
WHENEVER SQLERROR EXIT FAILURE
STARTUP UPGRADE;
EXIT
EOF
    if [[ $? -ne 0 ]]; then
        echo "Failed to start ${SID} in upgrade mode"
        exit 1
    fi
done