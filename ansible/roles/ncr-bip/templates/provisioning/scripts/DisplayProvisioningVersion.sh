# Get the version info of the provisioning jar
# Parameters: 1=Option (-all to return all version info)

# Setup provisioningCP environment variable
SCRIPT=`dirname $0`/provisioning_env.sh
echo Executing script: $SCRIPT
. $SCRIPT
echo ""

OPTION=$1
#echo Number of parameters: $#
if [ $# -gt 0 ]; then
   echo Showing all info...
else
   echo Showing only version info...
fi

echo Executing com.nomis.utils.Version class...

java -cp $provisioningCP com.nomis.utils.Version $OPTION

echo Finished.
