# Tests the populateProvisioningBOEGroups method in the Provisioning class
# This will also test a large portion of the provisioning code, including DB connectivity, BOE connectivity, logging amongst others
# Parameters: 1=<Cluster name>
#             2=force [Optional - Overrides the PopulateBOEGroupsTable property]

# Setup provisioningCP environment variable
SCRIPT=`dirname $0`/provisioning_env.sh
echo Executing script: $SCRIPT
. $SCRIPT
echo ""

CLUSTERNAME=$1
FORCEARG=$2
#echo Number of parameters: $#

if [ $# -lt 1 ]; then
   echo Incorrect number of parameters!
   echo "Usage: `basename $0` <cluster name> [force]"
else
   echo Populating the provisioning BOE groups DB table for cluster - $CLUSTERNAME $FORCEARG
   echo Executing com.nomis.main.Provisioning.populateProvisioningBOEGroups...
 
   STARTTIME=`date +%y%m%d%H%M%S`

   java -cp $provisioningCP com.nomis.main.Provisioning $CLUSTERNAME $FORCEARG

   ENDTIME=`date +%y%m%d%H%M%S`
   TIMETAKEN="$(expr $ENDTIME - $STARTTIME)"
#   echo Started at $STARTTIME  --  Ended at $ENDTIME
   echo Elapsed time: $TIMETAKEN secs 
  
   echo Finished. Check log file for results.
fi
