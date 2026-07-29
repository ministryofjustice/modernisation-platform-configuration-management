#!/bin/bash

#  Upgrade Oracle Application Express (APEX) manually before the database upgrade, we've droped it and reinstalled it.
      
# The database contains APEX version 3.2.1.00.12. Upgrade APEX to at least version 18.2.0.00.12.      
# Starting with Oracle Database Release 18, APEX is not upgraded automatically as part of the database upgrade. 
# Refer to My Oracle Support Note 1088970.1 for information about APEX installation and upgrades.

#!/bin/bash

APEX_COUNT=$(sqlplus -s / as sysdba <<EOF
WHENEVER SQLERROR EXIT FAILURE
set heading off feedback off verify off pages 0 echo off

SELECT COUNT(*) FROM dba_users WHERE username LIKE 'APEX_%';

EXIT
EOF
)

# Clean output (remove whitespace + CR)
APEX_COUNT=$(echo "$APEX_COUNT" | tr -d '\r' | xargs)

# Print result
# echo "$APEX_COUNT"

# Return result (Ansible-friendly)
if [ "$APEX_COUNT" -gt 0 ]; then
  echo "PRESENT" # APEX present
  exit 0
else
  echo "ABSENT" # Apex absent
  exit 1
fi