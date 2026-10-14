#!/bin/bash

# Update the default tape device to use if not explicitly set (pass SID as argument to override $ORACLE_SID)

. ~/.bash_profile

if [[ -n "$1" ]]; then
    export ORACLE_SID=$1
fi

rman target / <<EORMAN
CONFIGURE CHANNEL DEVICE TYPE 'SBT_TAPE' PARMS  'SBT_LIBRARY=${ORACLE_HOME}/lib/libosbws.so, ENV=(OSB_WS_PFILE=${ORACLE_HOME}/dbs/osbws.ora)';
exit;
EORMAN