#!/bin/bash

# Check Active Target is the 1st Standby Database

. ~/.bash_profile

ACTIVE_TARGET=$( echo "show configuration;" | dgmgrl / | grep "(*) Physical standby database" | awk '{print substr($1,length($1)-1)}')
# Check if target is not being Observed
NO_OBSERVER=$( echo "show configuration;" | dgmgrl / | grep -c "ORA-16820" )

if [[ "${ACTIVE_TARGET}" == "s1" && ${NO_OBSERVER} -eq 0 ]];
then
   echo "YES"
else
   echo "NO"
fi
