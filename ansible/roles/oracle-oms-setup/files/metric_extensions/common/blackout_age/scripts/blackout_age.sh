#!/bin/bash
#
#  We cannot check the Blackout Age from the host itself as, if it IS in a Blackout, it cannot then report the fact.
#  Therefore this script can only run on the OMS.
#
#  We explicitly exclude any host with the name sandpit on the assumption that this is regularly blacked out.
#

. ~/.bash_profile


# Function to retrieve passwords from AWS Secrets Manager for OEM
get_password() {
   USERNAME=$1
   if [[ "${ORACLE_SID}" == "EMREP" || "${ORACLE_SID}" == *RCVCAT* ]]; then
      aws secretsmanager get-secret-value --secret-id "/oracle/database/EMREP/shared-passwords" --region eu-west-2 --query SecretString --output text 2>/dev/null | jq -r .${USERNAME}
   fi
}

oratab=/etc/oratab
export ORACLE_SID=$(grep -v '^#' $oratab | grep -v AGENT | grep -v -i listener | grep -v -i asm | cut -d ":" -f1 | awk 'NF' | head -1) 
SYSMAN_PASSWORD=$(get_password sysman $ORACLE_SID)

export ORAENV_ASK=NO
. oraenv > /dev/null

export JAVA_HOME=$ORACLE_HOME/jdk/jre

EMCLI=/u01/app/oracle/product/mw135/bin/emcli

$EMCLI login -username=sysman -password=${SYSMAN_PASSWORD} -force 1>/dev/null 2>/dev/null
RETVAL=$?
if [[ $RETVAL -ne 0 ]]; then
   echo "Unable to login to EMCLI"
   exit 1
fi

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
