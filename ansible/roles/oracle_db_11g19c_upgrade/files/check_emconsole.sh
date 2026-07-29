#!/bin/bash

#  Remove EM console

EM_COUNT=$(sqlplus -s / as sysdba <<EOSQL
set heading off feedback off verify off pages 0 echo off
SELECT COUNT(*) FROM dba_registry WHERE comp_id = 'EM';
EXIT
EOSQL
)

# Clean output
EM_COUNT=$(echo $EM_COUNT | xargs)

# Print for debugging
#  echo "$EM_COUNT"

# Return code for Ansible
if [ "$EM_COUNT" -gt 0 ]; then
  echo "PRESENT"  # EM console exists
else
  echo "ABSENT"  # EM console not present
fi

exit 0


