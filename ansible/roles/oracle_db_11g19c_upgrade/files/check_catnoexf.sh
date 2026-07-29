#!/bin/bash

EXF_COUNT=$(sqlplus -s / as sysdba <<EOSQL
set heading off feedback off verify off pages 0 echo off
SELECT COUNT(*) FROM dba_registry WHERE comp_id like 'EXF';
EXIT
EOSQL
)

# Clean output
EXF_COUNT=$(echo $EXF_COUNT | xargs)

# Print result (useful for debugging)
echo "$EXF_COUNT"

# Return code for Ansible
if [ "$EXF_COUNT" -gt 0 ]; then
  echo "PRESENT"   # CATNOEXF exists
else
  echo "ABSENT"   # CATNOEXF not present
fi

