#!/bin/bash

OLAP_COUNT=$(sqlplus -s / as sysdba <<EOSQL
set heading off feedback off verify off pages 0 echo off
SELECT COUNT(*) FROM dba_registry WHERE comp_id IN ('AMD','APS','XOQ');
EXIT
EOSQL
)

# Clean output
OLAP_COUNT=$(echo $OLAP_COUNT | xargs)

# Print result (useful for debugging)
# echo "$OLAP_COUNT"

# Return code for Ansible
if [ "$OLAP_COUNT" -gt 0 ]; then
  echo "PRESENT"   # OLAP exists
else
  echo "ABSENT"   # OLAP not present
fi

