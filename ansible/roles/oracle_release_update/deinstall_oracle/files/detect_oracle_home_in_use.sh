
#!/bin/bash
#
#  Run a number of checks to confirm that the Oracle Home we are about to deinstall is not being used.
#

DEINSTALL_HOME=$1

# Determine current active database and grid homes
. ~oracle/.bash_profile
DB_ORACLE_HOME=${ORACLE_HOME}
export ORAENV_ASK=NO
export DB_SID=${ORACLE_SID}
export ORACLE_SID=+ASM
. oraenv >/dev/null
GI_ORACLE_HOME=${ORACLE_HOME}
export ORACLE_SID=${DB_SID}
. oraenv >/dev/null

if [[ $( ls -l /proc/*/exe 2>/dev/null | awk -F\-\> '{print $2}' | xargs dirname | grep -c "^${DEINSTALL_HOME}[/].*") -gt 0 ]];
then
   echo "[ERROR] Active processes found using ${DEINSTALL_HOME}."
   exit 1
fi

if [[ $(grep -c "[^#].*${DEINSTALL_HOME}:.*" /etc/oratab) -gt 0 ]];
then
   echo "[ERROR] References to ${DEINSTALL_HOME} found in /etc/oratab."
   exit 1
fi

if [[ $(grep "^ORA_CRS_HOME" /etc/init.d/init.ohasd | awk -F= '{print $2}') == "${DEINSTALL_HOME}" ]];
then
   echo "[ERROR] ${DEINSTALL_HOME} used in /etc/init.d/init.ohasd."
   exit 1
fi

if [[ $(. ~oracle/.bash_profile; srvctl config database | xargs -I {} srvctl config database -d {} | grep "Oracle home:" | cut -d: -f2 | sed 's/^ //') == "${DEINSTALL_HOME}" ]];
then
   echo "[ERROR] Oracle database server configuration contains ${DEINSTALL_HOME}."
   exit 1
fi

IFS=$'\n'
# When checking for references in the current DBS directory for Grid Infrastructure we can ignore the ab_+ASM.dat
# mapping file as this may contain environment variables set at the time of previous upgrade/patching which are
# not relevant.   This file is reset (to exclude these variables) by restarting ASM but this is not convenient in higher environments.
for x in $(ls -1 ${GI_ORACLE_HOME}/dbs/* | grep -v ab_+ASM.dat | xargs grep "${DEINSTALL_HOME}" 2>/dev/null);
do
   echo "[ERROR] Obsolete file reference in $x ${DEINSTALL_HOME}"
   exit 1
done

# Check if the ASM mapping file contains any references to the old home other than the known obsolete environment settings
for x in $(strings ${GI_ORACLE_HOME}/dbs/ab_+ASM.dat | grep "${DEINSTALL_HOME}" | grep -v ^oracleHome= | grep -v ^OPATCHAUTO_PERL_PATH= | grep -v ^HOME= | grep -v ^CLASSPATH=)
do
   echo "[ERROR] ASM Mapping File ab_+ASM.dat $x"
   exit 1
done


# If there are old controlfile snapshots present these may contain reference to previous Oracle Homes
# Simply create a new snapshot controlfile if required

INSTANCEID=$(wget -q -O - --tries=1 --timeout=20 http://169.254.169.254/latest/meta-data/instance-id)
ENVIRONMENT_NAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCEID}" "Name=key,Values=environment-name"  --query "Tags[].Value" --output text)
DELIUS_ENVIRONMENT=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCEID}" "Name=key,Values=delius-environment"  --query "Tags[].Value" --output text)
APPLICATION_NAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCEID}" "Name=key,Values=database" --query "Tags[].Value" --output text | cut -d_ -f1)
if [[ "${APPLICATION_NAME}" == "delius" ]]
then 
   # There is only one set of DBA secrets for Delius, whereas MIS has one per application name (MIS, BOE, DSD)
   APPLICATION_SECRET_PATH="oracle-db"
else
   APPLICATION_SECRET_PATH="oracle-${APPLICATION_NAME}-db"
fi
SYS_PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${ENVIRONMENT_NAME%-*}-${DELIUS_ENVIRONMENT}-${APPLICATION_SECRET_PATH}-dba-passwords --query SecretString --output text| jq -r .sys)

if [[ -f ${DB_ORACLE_HOME}/dbs/snapcf_${ORACLE_SID}.f ]];
then
   grep "${DEINSTALL_HOME}" ${DB_ORACLE_HOME}/dbs/snapcf_${ORACLE_SID}.f > /dev/null
   if [[ $? -eq 0 ]];
   then  
      rman target sys/${SYS_PASSWORD}@${ORACLE_SID} <<EORMAN
      backup current controlfile;
      exit
EORMAN
   fi

   # Sometimes it is necessary to repeat the above step to clear all references
   grep "${DEINSTALL_HOME}" ${DB_ORACLE_HOME}/dbs/snapcf_${ORACLE_SID}.f > /dev/null
   if [[ $? -eq 0 ]];
   then  
      rman target sys/${SYS_PASSWORD}@${ORACLE_SID} <<EORMAN
      backup current controlfile;
      exit
EORMAN
   fi

   # Delete snapshot control file as will be created on next backup if defined in RMAN configuration
   rm -f ${DB_ORACLE_HOME}/dbs/snapcf_${ORACLE_SID}.f

fi

# Check that the default RMAN SBT Channel is not pointing to the deinstall home
rman target sys/${SYS_PASSWORD}@${ORACLE_SID} <<EORMAN | grep "CONFIGURE CHANNEL DEVICE TYPE 'SBT_TAPE' PARMS" | awk -F= '{print $NF}' | tr -d ")';" | grep ${DEINSTALL_HOME}
SHOW CHANNEL;
exit;
EORMAN
if [[ $? -eq 0 ]];
then  
   echo "[ERROR] RMAN default channel contains ${DEINSTALL_HOME}"
   exit 1
fi

for x in $(grep -r "${DEINSTALL_HOME}" ${DB_ORACLE_HOME}/dbs/* 2>/dev/null);
do
   echo "[ERROR] Obsolete file reference in $x ${DEINSTALL_HOME}"
   exit 1
done

# Otherwise exit success (Oracle Home to be deinstalled does not appear to be in use)
exit 0
