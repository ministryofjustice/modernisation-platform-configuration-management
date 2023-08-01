#!/bin/bash

export ORACLE_SID=$1
export PARAMETERS_CSV=$2

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
SELECT name||','||value||','||DECODE(issys_modifiable,'FALSE','RESTART','NORESTART')
FROM   v\$parameter
WHERE  name IN ($PARAMETERS_CSV);
EXIT
EOF