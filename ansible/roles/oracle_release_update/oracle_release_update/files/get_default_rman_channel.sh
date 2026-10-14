#!/bin/bash

# Get the default tape device to use (pass SID as argument to override $ORACLE_SID)

. ~/.bash_profile

if [[ -n "$1" ]]; then
    export ORACLE_SID=$1
fi

rman target / <<EORMAN | grep "CONFIGURE CHANNEL DEVICE TYPE 'SBT_TAPE' PARMS" | awk -F= '{print $NF}' | tr -d ")';"
SHOW CHANNEL;
exit;
EORMAN