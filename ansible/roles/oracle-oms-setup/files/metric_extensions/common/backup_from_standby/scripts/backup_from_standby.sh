#!/bin/bash

. ~/.bash_profile

# Determine which catalog we are using by pinging both possible options.  Only 1 will resolve.
# Set the TRANSPORT_CONNECT_TIMEOUT to 3 seconds so we do not waste time trying to connect to
# the wrong catalog.
export TNS_DCAT="(DESCRIPTION=(TRANSPORT_CONNECT_TIMEOUT=3000ms)(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=rman-db-1.engineering-dev.probation.hmpps.dsd.io)(PORT=1521)))(CONNECT_DATA=(SERVICE_NAME=DCAT)))"
export TNS_PCAT="(DESCRIPTION=(TRANSPORT_CONNECT_TIMEOUT=3000ms)(ADDRESS_LIST=(ADDRESS=(PROTOCOL=TCP)(HOST=rman-db-1.engineering-prod)(PORT=1521)))(CONNECT_DATA=(SERVICE_NAME=PCAT)))"

tnsping ${TNS_PCAT} >/dev/null
if [[ $? == 0 ]]; then
   CATALOG=${TNS_PCAT}
else
   tnsping ${TNS_DCAT} >/dev/null
   if [[ $? == 0 ]]; then
      CATALOG=${TNS_DCAT}
   else
      echo "unable to connect to either catalog."
      exit 1
   fi
fi

RMANPWD=$(. /etc/environment && aws ssm get-parameters --region ${REGION} --with-decryption --name /${HMPPS_ENVIRONMENT}/${APPLICATION}/oracle-db-operation/rman/rman_password | jq -r '.Parameters[].Value' )

# For test purposes we will backup the smallest file in the database. We are not looking to create an actual backup;
# simply verify that a backup can be successfully run.
SMALLEST_FILE=$(echo -e "report schema;" | rman target / | grep DATAFILE | sort -n -k2 | head -1 | cut -d' ' -f 1)

BACKUP_TEST=$(
cat <<EORMAN | rman target /
connect catalog rman19c/${RMANPWD}@${CATALOG}
run {
allocate channel c1 device type sbt
  parms='SBT_LIBRARY=${ORACLE_HOME}/lib/libosbws.so,
  ENV=(OSB_WS_PFILE=${ORACLE_HOME}/dbs/osbws.ora)';
backup validate datafile ${SMALLEST_FILE};
release channel c1;
}
exit
EORMAN
)
RC=$?
ORA_COUNT=$(echo "${BACKUP_TEST}" | grep -c ORA-)
ERR_COUNT=$(echo "${BACKUP_TEST}" | grep -ci ERROR)
ORA_MESSAGE=$(echo "${BACKUP_TEST}" | grep ORA- | xargs)
ERR_MESSAGE=$(echo "${BACKUP_TEST}" | grep -i ERROR | xargs)

echo "$RC|${ORA_COUNT}|${ERR_COUNT}|${ORA_MESSAGE}|${ERR_MESSAGE}"
