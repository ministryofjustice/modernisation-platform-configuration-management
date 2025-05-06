#!/bin/bash

# Check Active Target is the 1st Standby Database is FSFO is enabled

. ~/.bash_profile

FSFO_ENABLED=$( echo "show configuration;" | dgmgrl / | grep -c "Fast-Start Failover: Enabled in Zero Data Loss Mode" )
ACTIVE_TARGET=$( echo "show configuration;" | dgmgrl / | grep "(*) Physical standby database" | awk '{print substr($1,length($1)-1)}')

if [[ "${ACTIVE_TARGET}" == "s1" && ${FSFO_ENABLED} -eq 1 ]];
then
   # OK is the Active Target database is the 1st Standby and FSFO is Enabled
   echo "OK"
else
   if [[ ${FSFO_ENABLED} -eq 0 ]];
   then
          # Also OK if FSFO is not enabled at all
	   echo "OK"
   else
           # Otherwise raise an error
   	   echo "NO"
   fi
fi
