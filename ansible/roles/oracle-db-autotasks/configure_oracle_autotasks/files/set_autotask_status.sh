#!/bin/bash

# Clients are enabled or disabled in all active windows
#
# Replace underscores with spaces when converting ansible variables
# back into the names of the clients

export ORACLE_SID=$1
export CLIENT_NAME=$2
export STATUS=$3

# Check Oracle SID exists
/usr/local/bin/dbhome ${ORACLE_SID}
if [[ $? -gt 0 ]]
then
echo "Invalid Oracle SID"
exit 123
fi

echo "Setting ${CLIENT_NAME} to ${STATUS}d"

export PATH=$PATH:/usr/local/bin; 
export ORAENV_ASK=NO ; 
. oraenv >/dev/null;

sqlplus -s /  as sysdba <<EOF
SET FEEDBACK ON
SET HEADING OFF
WHENEVER SQLERROR EXIT FAILURE
EXEC DBMS_AUTO_TASK_ADMIN.${STATUS}(client_name=>'${CLIENT_NAME}', operation=>NULL, window_name=>NULL);
EXIT
EOF