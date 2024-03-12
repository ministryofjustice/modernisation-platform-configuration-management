#!/bin/bash
#
#  We cannot check the Blackout Age from the host itself as, if it IS in a Blackout, it cannot then report the fact.
#  Therefore this script can only run on the OMS.
#
#  We explicitly exclude any host with the name sandpit on the assumption that this is regularly blacked out.
#

. ~/.bash_profile

EMCLI=/u01/app/oracle/oem/middleware/bin/emcli

SYSMAN_PASSWORD=$( . /etc/environment && aws ssm get-parameters --region ${REGION} --with-decryption --name /${HMPPS_ENVIRONMENT}/${APPLICATION}/oem-database/db/oradb_sysman_password | jq -r '.Parameters[].Value' )

$EMCLI login -username=sysman -password=${SYSMAN_PASSWORD} -force 1>/dev/null
$EMCLI sync 1>/dev/null
for HOST in $( $EMCLI get_targets -targets="host"  -format="name:script" -noheader | grep -v sandpit | awk '{print $NF}' );
do
   $EMCLI get_blackouts -hostnames="$HOST" -noheader -format="name:csv" | grep Started | while read BLACKOUT
   do
      NAME=$(echo $BLACKOUT | awk -F, '{print $1}')
      STARTDATE=$(echo $BLACKOUT | awk -F, '{print $5}')
      AGE=$(echo "scale=2; ($(date +%s) - $(date --date="$STARTDATE" +%s)) / (60*60*24)" | bc)
      echo "${HOST}_$NAME|$HOST|$NAME|$STARTDATE|$AGE"
   done
done
