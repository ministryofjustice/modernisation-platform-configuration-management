#!/bin/bash

# We cannot use spaces in the names of Autotask Client ansible variables
# so these are replaced with underscores when retrieved from the database

export ORACLE_SID=$1

# Check Oracle SID exists
/usr/local/bin/dbhome ${ORACLE_SID} >/dev/null
if [[ $? -gt 0 ]]
then
echo "Invalid Oracle SID"
exit 123
fi

export PATH=$PATH:/usr/local/bin; 
export ORAENV_ASK=NO ; 
. oraenv >/dev/null;

sqlplus -s /  as sysdba <<EOF
SET LINES 1000
SET PAGES 0
SET FEEDBACK OFF
SET HEADING OFF
WHENEVER SQLERROR EXIT FAILURE
SELECT   REPLACE(client_name,' ','_')||','||status
FROM     dba_autotask_client
ORDER BY client_name;
EXIT
EOF