#!/bin/bash

typeset -u RUN_MODE
export RUN_MODE=LIVE

typeset -u DEBUG_MODE
export DEBUG_MODE=N

export THISSCRIPT=`basename $0`
export THISDIRECTORY=`dirname $0`
export THISHOST=`uname -n`
typeset -u CATALOG_DB
typeset -u TARGET_DB
typeset -u SOURCE_DB

export TIMESTAMP=`date +"%Y%m%d%H%M"`
export RMANDATEFORMAT='YYMMDDHH24MISS';
export RMANDUPLICATELOGFILE=/home/oracle/admin/rman_scripts/rman_duplicate_${TIMESTAMP}.log
export RMANDUPLICATECMDFILE=/home/oracle/admin/rman_scripts/rman_duplicate.cmd

export SUCCESS_STATUS=0
export WARNING_STATUS=1
export ERROR_STATUS=9

#
#  If the restore datetime is not specified then we look up the highest SCN for backed up
#  archive logs in the RMAN catalog and use that.   NB: if no target date or SCN is
#  specified for the RMAN duplicate command will attempt to use the highest SCN for all
#  archive logs in the catalog regardless of whether these have been backed up or not, so
#  this should be avoided as, if they are not backed up, the duplicate may fail.
#
usage () {
  echo ""
  echo "Usage:"
  echo ""
  echo "  $THISSCRIPT -d <target db> -s <source db> -c <catalog db> -t <restore datetime> [ -f <spfile parameters> ] [-l]"
  echo ""
  echo "where"
  echo ""
  echo "  target db         = target database to clone to"
  echo "  source db         = source database to clone from"
  echo "  catalog db        = rman repository"
  echo "  restore datetime  = optional date time of production backup to restore from"
  echo "                      format [YYMMDDHH24MISS]"
  echo "  spfile parameters = extra spfile set parameters"
  echo "  -l                = use local disk backup only (do not allocate sbt channels)"
  echo ""

  exit $ERROR_STATUS
}

info () {
  T=`date +"%D %T"`
  echo "INFO : $THISSCRIPT : $T : $1"
  if [ "$DEBUG_MODE" = "Y" ]
  then
    read CONTINUE?"Press any key to continue "
  fi
}

warning () {
  T=`date +"%D %T"`
  echo "WARNING : $THISSCRIPT : $T : $1"
}

error () {
  T=`date +"%D %T"`
  echo "ERROR : $THISSCRIPT : $T : $1"
  exit $ERROR_STATUS
}

set_ora_env () {
  export ORAENV_ASK=NO
  export ORACLE_SID=$1
  . oraenv
  unset SQLPATH
  unset TWO_TASK
  unset LD_LIBRARY_PATH
  export NLS_DATE_FORMAT=YYMMDDHH24MI
}
 
validate () {
  ACTION=$1
  case "$ACTION" in
       user) info "Validating user"
             THISUSER=`id | cut -d\( -f2 | cut -d\) -f1`
             [ "$THISUSER" != "oracle" ] && error "Must be oracle to run this script"
             info "User ok"
             ;;
   targetdb) info "Validating target database"
             [ -z "$TARGET_DB" -o "$TARGET_DB" = "UNSPECIFIED" ] && usage
             grep ^${TARGET_DB}: /etc/oratab >/dev/null 2>&1 || error "Database $TARGET_DB does not exist on this machine"
             info "Target database ok"
             info "Set environment for $TARGET_DB"
             set_ora_env $TARGET_DB
             ;;
    catalog) info "Validating catalog database"
             if [ -z $CATALOG_DB ]
             then
               error "Catalog not specified, please specify catalog db"
             else
               . /etc/environment

               SSMNAME="/${ENVIRONMENT}/${APPLICATION}/oracle-db-operation/rman/rman_password"
               if [[ ${TARGET_DB} =~ .*OEM ]]
               then
                 SSMNAME="/${ENVIRONMENT}/${APPLICATION}/rman-database/db/rman_password"
               fi 
               RMANPASS=`aws ssm get-parameters --region ${REGION} --with-decryption --name ${SSMNAME} | jq -r '.Parameters[].Value'`
               [ -z ${RMANPASS} ] && error "Password for rman in aws parameter store ${SSMNAME} does not exist"
               CATALOG_CONNECT=rman19c/${RMANPASS}@"${CATALOG_DB}"
               CONNECT_TO_CATALOG=$(echo "connect catalog $CATALOG_CONNECT;")						
             fi
             info "Catalog ok"
             ;;
   datetime) info "Validating restore datetime format"
             if [ "${DATETIME}" != "LATEST" ]
             then
               X=`sqlplus -s ${CATALOG_CONNECT} << EOF
                  whenever sqlerror exit 1
                  set feedback off heading off verify off echo off
                  select to_date('${DATETIME}','${RMANDATEFORMAT}') from dual;
                  exit
EOF
` || error "Restore datetime ${DATETIME} format incorrect"
             fi
             ;;
          *) error "Incorrect parameter passed to vaidate function"
             ;;
  esac
}

remove_asm_directory () {
  VG=$1
  TARGETDB=$2
  sleep 10
  ORAENV_ASK=NO
  ORACLE_SID=+ASM
  . oraenv
  info "Remove directory ${TARGETDB} in ${VG} volume group"
  if asmcmd ls +${VG}/${TARGETDB} > /dev/null 2>&1
  then
     asmcmd rm -rf +${VG}/${TARGETDB} || error "Removing directory ${TARGETDB} in ${VG}/${TARGETDB}"
  else
    info "No asm directory in ${VG} to delete"
  fi
}

get_source_db_rman_details () {

  X=`sqlplus -s ${CATALOG_CONNECT} <<EOF
      whenever sqlerror exit failure
      set feedback off heading off verify off echo off

      with completion_times as
        (select a.dbid,
                decode(b.bck_type,'D',max(b.completion_time)) full_time,
                decode(b.bck_type,'I',max(b.completion_time)) incr_time,
                decode(b.bck_type,'L',max(b.completion_time)) arch_time,
                max(d.next_time)                              arch_next_time,
                max(d.next_change#)                           arch_scn
          from rc_database a,
               bs b,
               rc_database_incarnation c,
               rc_backup_archivelog_details d
          where a.name = '$SOURCE_DB'
          and a.db_key=b.db_key
          and a.db_key=c.db_key
          and a.dbinc_key = c.dbinc_key
          and b.bck_type is not null
          and b.bs_key not in (select bs_key
                              from rc_backup_controlfile
                              where autobackup_date is not null
                              or autobackup_sequence is not null)
          and b.bs_key not in (select bs_key
                              from  rc_backup_spfile)
          and b.db_key=d.db_key(+)
          and d.btype(+) = 'BACKUPSET'
          and b.bs_key=d.btype_key(+)
          group by a.dbid,b.bck_type)
      select 'DBID='||dbid,
             'FULL_TIME='||''''||to_char(max(full_time),'${RMANDATEFORMAT}')||'''',
             'INCR_TIME='||''''||to_char(max(incr_time),'${RMANDATEFORMAT}')||'''',
             'ARCH_TIME='||''''||to_char(max(arch_time),'${RMANDATEFORMAT}')||'''',
             'NEXT_TIME='||''''||to_char(max(arch_next_time),'${RMANDATEFORMAT}')||'''',
             'SCN='||to_char(max(arch_scn))
      from completion_times
      group by dbid;
EOF
`
  eval $X || error "Getting $SOURCE_DB rman details"
  info "${SOURCE_DB} dbid = ${DBID}"
  if [ "${DATETIME}" = "LATEST" ]
  then
    info "Restore time = ${NEXT_TIME}"
    info "Restore SCN  = ${SCN}"
  else
    info "Restore time = ${DATETIME}"
  fi
}

build_rman_command_file () {

  V_PARAMETER=v\$parameter
  X=`sqlplus -s "/ as sysdba" <<EOF
     whenever sqlerror exit 1
     set feedback off heading off verify off echo off
     select 'CPU_COUNT="'||value||'"' from $V_PARAMETER
     where name = 'cpu_count';
     exit
EOF
` || "Cannot determine cpu count"
  eval $X
  info "cpu count = $CPU_COUNT"

  >$RMANDUPLICATECMDFILE
  echo "run {" >>$RMANDUPLICATECMDFILE
  TYPE="sbt\n  parms='SBT_LIBRARY=${ORACLE_HOME}/lib/libosbws.so,\n  ENV=(OSB_WS_PFILE=${THISDIRECTORY}/osbws_duplicate.ora)';"
  for (( i=1; i<=${CPU_COUNT}; i++ ))
  do
    if [[ "${LOCAL_DISK_BACKUP}" == "TRUE" ]]
    then
       echo -e "  allocate auxiliary channel c${i} device type DISK;" >> $RMANDUPLICATECMDFILE
    else
       echo -e "  allocate auxiliary channel c${i} device type $TYPE" >> $RMANDUPLICATECMDFILE
    fi
  done
  get_source_db_rman_details
  echo "  duplicate database ${SOURCE_DB} dbid ${DBID} to ${TARGET_DB}" >> $RMANDUPLICATECMDFILE
  echo "  spfile " >> $RMANDUPLICATECMDFILE
  if [[ "${source_db}" != "${target_db}" ]]
  then
    echo "    parameter_value_convert ('${SOURCE_DB}','${TARGET_DB}','${source_db}','${target_db}')" >> $RMANDUPLICATECMDFILE
    echo "    set db_file_name_convert='+DATA/${SOURCE_DB}','+DATA/${TARGET_DB}'" >> $RMANDUPLICATECMDFILE
    echo "    set log_file_name_convert='+DATA/${SOURCE_DB}','+DATA/${TARGET_DB}','+FLASH/${SOURCE_DB}','+FLASH/${TARGET_DB}'" >> $RMANDUPLICATECMDFILE
  fi
  echo "    set fal_server=''" >> $RMANDUPLICATECMDFILE
  echo "    set log_archive_config=''" >> $RMANDUPLICATECMDFILE
  echo "    set log_archive_dest_2=''" >> $RMANDUPLICATECMDFILE
  echo "    set log_archive_dest_3=''" >> $RMANDUPLICATECMDFILE
  if [ "${SPFILE_PARAMETERS}" != "UNSPECIFIED" ]
  then
    for PARAM in ${SPFILE_PARAMETERS[@]}
    do
      echo "    set ${PARAM}" >> $RMANDUPLICATECMDFILE
    done
  fi
  # Source database and target database maybe the same name. Introduce nofilenamecheck to avoid rman failures.
  if [[ "${source_db}" == "${target_db}" ]]
  then
    echo "  nofilenamecheck " >> $RMANDUPLICATECMDFILE
  fi
  if [ "${DATETIME}" != "LATEST" ]
  then
    echo "  until time \"TO_DATE('${DATETIME}','${RMANDATEFORMAT}')\";" >> $RMANDUPLICATECMDFILE
  else  
    echo "  until scn ${SCN};" >> $RMANDUPLICATECMDFILE 
  fi

  echo "}" >>$RMANDUPLICATECMDFILE
  echo "exit"	>>$RMANDUPLICATECMDFILE
}

add_spfile_asm () {
  SPFILE=${ORACLE_HOME}/dbs/spfile${TARGET_DB}.ora
  PFILE=${ORACLE_HOME}/dbs/init${TARGET_DB}.ora
  ASMSPFILE=+DATA/${TARGET_DB}/spfile${TARGET_DB}.ora

  info "Update pfile to point to spfile in ASM"
  echo "SPFILE='${ASMSPFILE}'" > ${PFILE}

  info "Restart database using asm spfile"
  TARGET_DB_STATUS=$(srvctl status database -d ${TARGET_DB})
  if [[ ${TARGET_DB_STATUS} =~ 'Database is running' ]]
  then
    srvctl stop database -d ${TARGET_DB} || error "Stopping database ${TARGET_DB}"
  fi
  srvctl start database -d ${TARGET_DB} || error "Starting database ${TARGET_DB}"
}

enable_bct () {
  V_BLOCK_CHANGE_TRACKING=v\$block_change_tracking
  X=`sqlplus -s "/ as sysdba" <<EOF
     whenever sqlerror exit failure
     set feedback off heading off verify off echo off
     select 'STATUS="'||status||'"' from $V_BLOCK_CHANGE_TRACKING;
     exit
EOF
` || error "Cannot determine block change tracking status"
  eval $X
  info "Block Change Tracking = $STATUS"
  if [ "$STATUS" = "DISABLED" ]
  then
      if sqlplus -s / as sysdba
      then
         info "Block Change Tracking now enabled"
      else
         error "Unable to enable Block Change Tracking"
      fi <<EOSQL
         whenever sqlerror exit 1
         set feedback off heading off verify off echo off
         alter database enable block change tracking;
         exit 
EOSQL
  else
     info "Block Change Tracking is already enabled"
  fi
}

recreate_password_file () {
SYS_PASS=$1

set_ora_env +ASM
# First we must remove the old password file location from Grid Config otherwise it will not let us create a new one
srvctl modify database -d ${TARGET_DB} -pwfile
echo ${SYS_PASS} | orapwd file="+DATA/${TARGET_DB}/orapw${TARGET_DB}" dbuniquename="${TARGET_DB}"

set_ora_env ${TARGET_DB} 
}

function exists_in_list() {
    # Check if item is in list
    VALUE=$1
    DELIMITER=$2
    LIST="$3"
    DELIMITED_LIST=$(echo $LIST | tr "$DELIMITER" '\n')
    echo $VALUE | grep -F -q -x "${DELIMITED_LIST}" && echo "Found" || echo "Absent"
}

restore_db_passwords () {

  info "Looking up passwords to in aws ssm secrets to restore"
  INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
  APPLICATION=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=application" --query 'Tags[0].Value' --output text)
  ENVIRONMENT_NAME=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=environment-name" --query 'Tags[0].Value' --output text)
  DELIUS_ENVIRONMENT=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=delius-environment" --query 'Tags[0].Value' --output text)
  SYSTEMDBUSERS=(sys system dbsnmp)
  if [ "$APPLICATION" = "delius" ]
  then
    DBUSERS+=(delius_app_schema delius_pool delius_analytics_platform gdpr_pool delius_audit_dms_pool mms_pool contact_search_pool)
    # Add Probation Integration Services by looking up the Usernames by their path in the AWS Secrets (there may be several of these)
    # We suppress any lookup errors for integration users as these may not exist
    PROBATION_INTEGRATION_USERS=$(aws secretsmanager get-secret-value --secret-id ${SECRET_ID} --query SecretString --output text 2>/dev/null | jq -r 'keys | join(" ")')
    DBUSERS+=( ${PROBATION_INTEGRATION_USERS[@]} )
  elif [ "$APPLICATION" = "mis" ]
  then
    DBUSERS+=(mis_landing ndmis_abc ndmis_cdc_subscriber ndmis_loader ndmis_working ndmis_data)
    DBUSERS+=(dfimis_landing dfimis_abc dfimis_subscriber dfimis_data dfimis_working dfimis_loader)
  fi

  info "Change password for all db users"
  DBUSERS+=( ${SYSTEMDBUSERS[@]} )
  for USER in ${DBUSERS[@]}
  do
    # Pattern for AWS Secrets path for Probation Integration Users differs from other Oracle user accounts
    if [[ "$HMPPS_ROLE" == "delius" && $(exists_in_list "${USER}" " " "${PROBATION_INTEGRATION_USERS[*]}" ) == "Found" ]];
    then
       SECRET_ID="${ENVIRONMENT_NAME}-${DELIUS_ENVIRONMENT}-delius-integration-passwords"
    else
       SECRET_ID="${ENVIRONMENT_NAME}-${DELIUS_ENVIRONMENT}-delius-dba-passwords"
    fi
    USERPASS=$(aws secretsmanager get-secret-value --secret-id ${SECRET_ID} --query SecretString --output text | jq -r ".${USER}")
    # Ignore absense of Audit Preservation and Probation Integration Users as they may not exist in all environments
    if [[ -z ${USERPASS} && $(exists_in_list "${USER}" " " "delius_audit_pool ${PROBATION_INTEGRATION_USERS[*]}") != "Found" ]];
    then
       error "Password for $USER in AWS Secret  ${SECRET_ID} does not exist"
    fi
    if [[ -z ${USERPASS} && $(exists_in_list "${USER}" " " "delius_audit_pool ${PROBATION_INTEGRATION_USERS[*]}") == "Found" ]];
    then
       info "$USER not configured in this environment - skipping"
    else
        info "Change password for $USER"
        # Accounts may have become locked if client applications are trying to connect immediately after the database
        # is opened so we ensure that all accounts are unlocked on changing the passwords.  No error is raised if the
        # account is not already locked.
        sqlplus -s / as sysdba << EOF
        alter user $USER identified by "${USERPASS}" account unlock;
        exit
EOF
    fi
    # The Database Password File is Stored in ASM and will have been wiped by the refresh.
    # Therefore whilst we are setting the SYS password, recreate the Password File.
    if [[ "${USER}" == "sys" ]];
    then
       recreate_password_file "${USERPASS}"
    fi
  done
}

configure_rman_archive_deletion_policy () {
    rman target / << EOF > /dev/null
    CONFIGURE ARCHIVELOG DELETION POLICY TO BACKED UP 1 TIMES TO 'SBT_TAPE';
    exit
EOF

}

recreate_temporary_tablespaces () {

info "Recreate temporary tablespaces with no tempfiles"

sqlplus -s / as sysdba << EOF

declare

l_default_temporary_tablespace database_properties.property_value%type;

begin

  select property_value
  into l_default_temporary_tablespace
  from database_properties 
  where property_name = 'DEFAULT_TEMP_TABLESPACE';

  for t in (select s.name,
                  count(*) no_tempfiles
            from v\$tempfile f
            join v\$tablespace s ON s.ts# = f.ts#
            where f.name = '+DATA'
            group by s.name)
  loop

    if t.no_tempfiles > 0
    then
      if t.name = l_default_temporary_tablespace
      then
        execute immediate q'[create temporary tablespace duptemp tempfile '+data']';
        execute immediate 'alter database default temporary tablespace duptemp';
      end if;
      execute immediate 'drop tablespace '||t.name;
      for n in 1..t.no_tempfiles
      loop
        if n = 1
        then
          execute immediate 'create temporary tablespace '||t.name||q'[ tempfile '+DATA']';
        else
          execute immediate 'alter tablespace '||t.name||q'[ add tempfile '+DATA']';
        end if;
      end loop;
    end if;
    if t.name = l_default_temporary_tablespace
    then
      execute immediate 'alter database default temporary tablespace '||t.name;
      execute immediate 'drop tablespace duptemp including contents and datafiles';
    end if;
  end loop;

end;
/
exit

EOF
}

run_datapatch() {
    info "Run datapatch"
    cd ${ORACLE_HOME}/OPatch
    ./datapatch >/dev/null 2>&1
    [ $? -ne 0 ] && error "Running datapatch"
}

post_actions () {
  add_spfile_asm
  enable_bct
  if [[ "${target_db}" != "${source_db}" ]]
  then
    restore_db_passwords
  fi
  # Ensure the archive deletion policy is set correctly for the primary database
  configure_rman_archive_deletion_policy
  # Ensure the tempfiles for temporary exist other wise recreate the temporary tablespace
  recreate_temporary_tablespaces
  # Run datapatch in case the source db is at lower release update level
  run_datapatch
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
info "Starts"
unset ORACLE_SID
info "Retrieving arguments"
[ -z "$1" ] && usage

TARGET_DB=UNSPECIFIED
DATETIME=LATEST
SSM_PARAMETER=UNSPECIFIED
SPFILE_PARAMETERS=UNSPECIFIED
while getopts "d:s:c:t:p:f:l" opt
do
  case $opt in
    d) TARGET_DB=$OPTARG ;;
    s) SOURCE_DB=$OPTARG ;;
    c) CATALOG_DB=$OPTARG ;;
    t) DATETIME=${OPTARG} ;;
    p) SSM_PARAMETER=${OPTARG} ;;
    f) SPFILE_PARAMETERS=${OPTARG} ;;
    l) LOCAL_DISK_BACKUP=TRUE ;;
    *) usage ;;
  esac
done

info "Target         = $TARGET_DB"
info "Source         = $SOURCE_DB"
info "Catalog db     = $CATALOG_DB"
info "Restore Datetime = ${DATETIME}"
info "SSM parameter    = ${SSM_PARAMETER}"
[[ "${LOCAL_DISK_BACKUP}" == "TRUE" ]] && info "Local Disk Backup = ENABLED"
target_db=$(echo "${TARGET_DB}" | tr '[:upper:]' '[:lower:]')
source_db=$(echo "${SOURCE_DB}" | tr '[:upper:]' '[:lower:]')

validate user
info "Execute $THISUSER bash profile"
. $HOME/.bash_profile
validate targetdb
validate catalog
validate datetime

# info "Get compatible value before shutting down"
# V_PARAMETER=v\$parameter
# if ! X=`sqlplus -s / as sysdba <<EOF
#    whenever sqlerror exit 1
#    set feedback off heading off verify off echo off
#    select 'COMPATIBLE_VALUE='||value 
#    from $V_PARAMETER
#    where name='compatible';
#    exit;
# EOF
# `
# then
  #  info "Cannot determine compatible value from database; falling back to most recently logged value"
  #  COMPATIBLE_VALUE=$( egrep -E "^[[:space:]]+compatible" $ORACLE_BASE/diag/rdbms/${ORACLE_SID}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log $ORACLE_BASE/diag/rdbms/${ORACLE_SID,,}/${ORACLE_SID}/trace/alert_${ORACLE_SID}.log | tail -1 | sed 's/"//g' | awk '{print $NF}'  )
# else
#    eval $X
# fi
# [ -z $COMPATIBLE_VALUE ] && error "Cannot determine compatible value"

if [ "${SPFILE_PARAMETERS}" != "UNSPECIFIED" ]
then
  for PARAM in ${SPFILE_PARAMETERS[@]}
  do
    if [[ ${PARAM} =~ compatible.* ]]
    then  
      COMPATIBLE=${PARAM//\'/}
    fi
  done
fi

info "Shutdown ${TARGET_DB}"
  sqlplus -s / as sysdba <<EOF
  shutdown abort;
EOF

info "Modify database using Server Control with correct spfile location"
srvctl modify database -d ${TARGET_DB} -p "+DATA/${TARGET_DB}/spfile${TARGET_DB}.ora"

remove_asm_directory DATA ${TARGET_DB}
remove_asm_directory FLASH ${TARGET_DB}

info "Create ${TARGET_DB} in +DATA in readiness for duplicate"
asmcmd mkdir +DATA/${TARGET_DB}

info "Set environment for ${TARGET_DB}"
set_ora_env ${TARGET_DB}

INI_FILES=(${ORACLE_HOME}/dbs/*${TARGET_DB}*.ora)
if [[ -f ${INI_FILES[0]} ]]
then
   info "Remove all references to all ${TARGET_DB} initialization files to start fresh"
   rm ${ORACLE_HOME}/dbs/*${TARGET_DB}*.ora || error "Removing ${TARGET_DB} initialization files"
fi

DUPLICATEPFILE=${ORACLE_HOME}/dbs/init${TARGET_DB}_duplicate.ora
info "Create ${DUPLICATEPFILE} pfile"
echo "db_name=${TARGET_DB}" > ${DUPLICATEPFILE}
echo "${COMPATIBLE}" >> ${DUPLICATEPFILE}

info "Place ${TARGET_DB} in nomount mode"
if ! sqlplus -s / as sysdba << EOF
  whenever sqlerror exit failure
  startup force nomount pfile=${DUPLICATEPFILE}
EOF
then
   error "Placing ${TARGET_DB} in nomount mode"
fi

info "Generating rman command file"
build_rman_command_file

info "Running rman cmd file $RMANDUPLICATECMDFILE"
info "Please check progress ${RMANDUPLICATELOGFILE} ..."
rman log $RMANDUPLICATELOGFILE <<EOF > /dev/null
connect auxiliary /
$CONNECT_TO_CATALOG
@$RMANDUPLICATECMDFILE
EOF
info "Checking for errors"
grep -i "ERROR MESSAGE STACK" $RMANDUPLICATELOGFILE>/dev/null 2>&1 && error "Rman Duplicate reported errors" || info "RMAN Duplicate Completed successfully"
info "Perform post actions"
post_actions

# Exit with success status if no error found
trap "" ERR EXIT
exit 0
