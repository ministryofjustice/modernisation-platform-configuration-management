# Tests the Logon class

# Setup provisioningCP environment variable
SCRIPT=`dirname $0`/provisioning_env.sh
echo Executing script: $SCRIPT
. $SCRIPT
echo ""

echo Executing com.nomis.utils.Logon class...
 
STARTTIME=`date +%y%m%d%H%M%S`

java -cp $provisioningCP com.nomis.utils.Logon

ENDTIME=`date +%y%m%d%H%M%S`
TIMETAKEN="$(expr $ENDTIME - $STARTTIME)"
#echo Started at $STARTTIME  --  Ended at $ENDTIME
echo Elapsed time: $TIMETAKEN secs 
  
echo Finished. Check log file for results.
