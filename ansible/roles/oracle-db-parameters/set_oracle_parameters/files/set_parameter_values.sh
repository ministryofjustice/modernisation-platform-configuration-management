#!/bin/bash

export ORACLE_SID=$1
export PARAMETER_NAME=$2
export PARAMETER_VALUE=$3

# Check Oracle SID exists
/usr/local/bin/dbhome ${ORACLE_SID}
if [[ $? -gt 0 ]]
then
echo "Invalid Oracle SID"
exit 123
fi

echo "Setting $PARAMETER_NAME to $PARAMETER_VALUE"

export PATH=$PATH:/usr/local/bin; 
export ORAENV_ASK=NO ; 
. oraenv >/dev/null;

sqlplus -s /  as sysdba <<EOF
SET LINES 1000
SET PAGES 0
SET FEEDBACK ON
SET HEADING OFF
WHENEVER SQLERROR EXIT FAILURE
ALTER SYSTEM SET $PARAMETER_NAME = $PARAMETER_VALUE ;
EXIT
EOF