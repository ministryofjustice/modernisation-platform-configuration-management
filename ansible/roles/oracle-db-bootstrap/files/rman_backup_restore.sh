#!/bin/bash

THISSCRIPT=`basename $0`
CURRDATE=`date +"20%y%m%d"`
CURRHOUR=`date +"%H"`
CURRMIN=`date +"%M"`
TIMESTAMP="${CURRDATE}${CURRHOUR}${CURRMIN}"
CPU_COUNT=`grep processor /proc/cpuinfo | wc -l`

info () {
  T=`date +"%D %T"`
  echo -e "INFO : $THISSCRIPT : $T : $1"
}

error () {
  T=`date +"%D %T"`
  echo -e "ERROR : $THISSCRIPT : $T : $1"
  exit 1
}

set_ora_env () {
  ORAENV_ASK=NO
  ORACLE_SID=$1
  . /usr/local/bin/oraenv > /dev/null
  unset SQLPATH
  unset TWO_TASK
  unset LD_LIBRARY_PATH
}

check_vgsize () {
  ORAENV_ASK=NO
  ORACLE_SID=+ASM
  . oraenv
  info "`asmcmd lsdg --suppressheader DATA | awk '{printf ("Disk group DATA FreeMb: %s\n", $8)}'`"
  info "`asmcmd lsdg --suppressheader FLASH  | awk '{printf ("Disk group FLASH FreeMb: %s\n", $8)}'`"
}

remove_directory () {
  ORAENV_ASK=NO
  ORACLE_SID=+ASM
  . oraenv
  VG=$1
  TARGETDB=$2
  info "Remove directories in $VG volume group"
  asmcmd ls +$VG/$TARGETDB > /dev/null 2>&1
  if [ $? -eq 0 ]
  then
    asmcmd rm -rf +$VG/$TARGETDB
    [ $? -ne 0 ] && error "Removing directories in $VG/$TARGETDB"
  else
    info "No asm directories in $VG to delete"
  fi
}

database_operation () {
  OPERATION=$1
  info "$OPERATION of $TARGETDB"
  ORACLE_SID=+ASM
  . oraenv
  case $OPERATION in
    stop) DBSTATUS=`srvctl status database -d $TARGETDB`
          if [ `echo $DBSTATUS | grep "is running" | wc -l` -gt 0 ]
          then
            srvctl stop database -d $TARGETDB -o abort
            sleep 10
          else
            ORACLE_SID=$TARGETDB
            . oraenv
            sqlplus / as sysdba << EOF
              shutdown abort;
              exit;
EOF
          fi
          ;;
   start) srvctl start database -d $TARGETDB
          ;;
  esac
  [ $? -ne 0 ] && error "$OPERATION of $TARGETDB"
}


usage () {
  echo ""
  echo "Usage:"
  echo ""
  echo "  $THISSCRIPT -t <targetsid> -l <level> -d <stagedir> -f <final>"
  echo ""
  echo "  targetsid = target oracle sid"
  echo "  level     = incremental level [0|1|cold|seed]"
  echo "  stagedir  = RMAN backup directory"
  echo "  final     = final incremental [Y|N] default N"
  echo ""
  exit 1
}

validate_parameters () {

  [ -z "$DBSID" -o "$DBSID" = "UNSPECIFIED" ] && error "Please specify Oracle sid"
  grep ^${DBSID}: /etc/oratab >/dev/null 2>&1
  [ $? -ne 0 ] && error "Oracle sid $DBSID does not exist on this machine"

  case $LEVEL in
    0|1|cold|seed) info "Backup type = $LEVEL" ;;
      *) error "Please secify correct incremental level" ;;
  esac

  [ ! -d $STAGINGDIR ] && error "Staging directory does not exist or incorrect permissions"
  info "Staging Directory =  $STAGINGDIR"

  case $FINAL in
    N|Y) info "Final incremental = $FINAL" ;;
      *) error "Please secify correct final flag" ;;
  esac

}

download_seedbackup_from_s3() {

  info "Sync S3 bucket with backup staging directory"
  . /etc/environment
  BUCKETDIRECTORYNAME="`echo $S3_ORACLEDB_BACKUPS_ARN | awk -F: '{print $NF}'`/seed/delius/"
  aws s3 sync s3://$BUCKETDIRECTORYNAME $STAGINGDIR --exclude "*" --include "*"
  [ $? -ne 0 ] && error "Issue syncing S3 bucket with staging directory"

  SPFILEPIECE=`ls -1 $STAGINGDIR/seed*_sf_*`
  CONTROLPIECE=`ls -1 $STAGINGDIR/seed*_cf_*`
  DATAFILEDIRECTORIES="+DATA/`ls -1 $STAGINGDIR/seed* | cut -d_ -f4 | sort -u`"
}

check_rman_logfle_no () {

  PATTERN=$1
  RMANLOGFILENO=`ls -l $STAGINGDIR/rman_backup_*${PATTERN}*.log | wc -l`
  [ $RMANLOGFILENO -ne 1 ] && error "RMAN ${PATTERN} logfile does not exist or more than one"
  RMANLOGFILE=`ls $STAGINGDIR/rman_backup_*${PATTERN}*.log`
  info "Rman log file = ${RMANLOGFILE}"
}

check_rman_logfile () {

  info "Find correct log file"
  if [ "$LEVEL" = "0" ]
  then
    info "Check number of rman log files"
    check_rman_logfle_no level0
    info "Find spfile and controlfile backup piece from level0 log file"
    SPFILEPIECE=$STAGINGDIR/`grep "Piece Name:" $RMANLOGFILE | grep _sf_ | awk -F'/' '{print $NF}'`
    CONTROLPIECE=$STAGINGDIR/`grep "Piece Name:" $RMANLOGFILE | grep _cf_ | awk -F'/' '{print $NF}'`
    DATAFILEDIRECTORIES=$(dirname `grep "input datafile file number" $RMANLOGFILE | cut -d'=' -f3`| sort -u)
    info "Spfile backup piece: $SPFILEPIECE"
    info "Controlfile backup piece: $CONTROLPIECE"
  elif [ "$LEVEL" = "1" ]
  then
    info "Check number of rman log files"
    check_rman_logfle_no level1
    info "Find SCN from level1 log file and add 2"
    SCN=`grep "beyond SCN " $RMANLOGFILE | cut -d' ' -f7`
    SCN=`expr $SCN + 2`
    info "SCN = $SCN"
  elif [ "$LEVEL" = "cold" ]
  then
    info "Check number of rman log files"
    check_rman_logfle_no cold
    info "Find spfile and controlfile backup piece from level0 log file"
    SPFILEPIECE=$STAGINGDIR/`grep "piece handle=" $RMANLOGFILE | grep _sf_ | awk -F'/' '{print $NF}' | cut -d' ' -f1`
    CONTROLPIECE=$STAGINGDIR/`grep "piece handle=" $RMANLOGFILE | grep _cf_ | awk -F'/' '{print $NF}'| cut -d' ' -f1`
    DATAFILEDIRECTORIES=$(dirname `grep "input datafile file number" $RMANLOGFILE | cut -d'=' -f3`| sort -u)
    info "Spfile backup piece: $SPFILEPIECE"
    info "Controlfile backup piece: $CONTROLPIECE"
  fi

}

# ------------------------------------------------------------------------------
# Restore control file
# ------------------------------------------------------------------------------

restore_controlfile () {

  info "Restore control file"
  echo "restore controlfile from '${CONTROLPIECE}';" > $STAGINGDIR/rmanrestorecontrolfile.cmd
  rman target / cmdfile $STAGINGDIR/rmanrestorecontrolfile.cmd log $STAGINGDIR/rmanrestorecontrolfile.log > /dev/null
  [ $? -ne 0 ] && error "Restoring controlfiles"

  let i=0
  for CONTROLFILE in ` grep "output file name" $STAGINGDIR/rmanrestorecontrolfile.log | cut -d'=' -f2`
  do
    i=`expr $i + 1`
    [ $i -eq 1 ] && CONTROLFILE1=$CONTROLFILE
    [ $i -eq 2 ] && CONTROLFILE2=$CONTROLFILE
  done

  info "Replace control_files in ${PFILE}"
  sed -e "s|.*control.*|\*\.control_files='$CONTROLFILE1','$CONTROLFILE2'|" ${TEMPPFILE} > ${PFILE}

  info "Mount instance with ${PFILE}"
  sqlplus -s / as sysdba <<EOF
    shutdown abort
    startup mount pfile='${PFILE}'
    exit
EOF
  [ $? -ne 0 ] && error "Starting mount"

}

# ------------------------------------------------------------------------------
# crosscheck and catalog database if not already and restore database
 # ------------------------------------------------------------------------------

restore_database () {

  if [ "$LEVEL" = "0" ]
  then
    STARTWITH=level0
    TAG='DB_LEVEL0'
  elif [ "$LEVEL" = "cold" ]
  then
    STARTWITH=cold
    TAG='DB_COLD'
  elif [ "$LEVEL" = "seed" ]
  then
    STARTWITH=seed
    TAG='DB_SEED'
  fi

  RMANRESTORECMD=$STAGINGDIR/rmanrestore${STARTWITH}.cmd
  RMANRESTORELOG=$STAGINGDIR/rmanrestore${STARTWITH}.log

  info "Restore $STARTWITH backup"
  echo "crosscheck backup;"                             > $RMANRESTORECMD
  echo "delete expired backup;"                         >> $RMANRESTORECMD
  echo "catalog start with '${STAGINGDIR}/${STARTWITH}';" >> $RMANRESTORECMD
  echo "run "                                           >> $RMANRESTORECMD
  echo "{"                                              >> $RMANRESTORECMD
  echo "  set newname for database to '+DATA';"         >> $RMANRESTORECMD
  for (( i=1; i<=${CPU_COUNT}; i++ ))
  do
    echo "  allocate channel ch${i} device type disk;"  >> $RMANRESTORECMD
  done
  echo "  restore database from tag='${TAG}';"          >> $RMANRESTORECMD
  echo "  switch datafile all;"                         >> $RMANRESTORECMD
  for (( i=1; i<=${CPU_COUNT}; i++ ))
  do
    echo "  release channel ch${i};"                    >> $RMANRESTORECMD
  done
  echo "}"                                              >> $RMANRESTORECMD
  rman target /  cmdfile $RMANRESTORECMD log $RMANRESTORELOG >/dev/null
  [ $? -ne 0 ] && error "Restoring ${STARTWITH} backup" || info "Restored ${STARTWITH} backup"

}

# ------------------------------------------------------------------------------
# Recover database
# ------------------------------------------------------------------------------

recover_database () {

  RMANRECOVERCMD=$STAGINGDIR/rmanrecover${STARTWITH}.cmd
  RMANRECOVERLOG=$STAGINGDIR/rmanrecover${STARTWITH}.log
  info "Recover level 1 backup"
  echo "catalog start with '${STAGINGDIR}/level${LEVEL}';" > $RMANRECOVERCMD
  echo "run"						>> $RMANRECOVERCMD
  echo "{"						>> $RMANRECOVERCMD
  for (( i=1; i<=${CPU_COUNT}; i++ ))
  do
    echo "  allocate channel ch${i} device type disk;"  >> $RMANRECOVERCMD
  done
  echo "  recover database until scn ${SCN};"		>> $RMANRECOVERCMD
  for (( i=1; i<=${CPU_COUNT}; i++ ))
  do
    echo "  release channel ch${i};"  >> $RMANRECOVERCMD
  done
  echo "}"						>> $RMANRECOVERCMD
  rman target /  cmdfile $RMANRECOVERCMD log $RMANRECOVERLOG >/dev/null
  [ $? -ne 0 ] && error "Recovering level 1 backup" || info "Recovered level 1 backup"

}

# ------------------------------------------------------------------------------
# Disable block change tracking if enabled otherwise it will fail
# ------------------------------------------------------------------------------
disable_block_change_tracking () {

  info "Disable block change tracking if enabled otherwise it will fail"
  sqlplus -s / as sysdba <<EOF
  whenever sqlerror exit failure
  set head off pages 1000 feed off termout off
  declare
    v_status  v\$block_change_tracking.status%type;
  begin
    select status into v_status from v\$block_change_tracking;
  exception
  when others then
    execute immediate 'alter database disable block change tracking';
  end;
  /

EOF
}

# ------------------------------------------------------------------------------
# Rename redo logfiles and open database
# ------------------------------------------------------------------------------
rename_redologfiles () {

  info "Rename redo logs before opening"
    sqlplus -s / as sysdba << EOF
    whenever sqlerror exit failure
    set head off pages 1000 feed off termout off
    declare
      cursor c1 is
        select 'alter database rename file '||''''||member||''''||' to '||''''||decode(r,1,'+DATA',2,'+FLASH')||'''' cmd1,
        case
          when r = 2
          then
            'alter database clear logfile group '||group#
        end cmd2
        from (select lf.member,
              l.group#,
              row_number() over (partition by lf.group# order by lf.group#) r
        from v\$log l,
              v\$logfile lf
        where l.group# = lf.group#);
      sql_stmt varchar2(400);
    begin
      for r1 in c1
      loop
        sql_stmt := r1.cmd1;
        execute immediate sql_stmt;
        if r1.cmd2 is not null
        then
          sql_stmt := r1.cmd2;
          execute immediate sql_stmt;
        end if;
      end loop;
      execute immediate 'alter database open resetlogs';
    end;
    /
    exit
EOF
    [ $? -ne 0 ] && error "Renaming redo failed/opening database"
}

# ------------------------------------------------------------------------------
# Add redo group with fixed size and number, drop unwanted ones
# ------------------------------------------------------------------------------
add_drop_redologfiles () {

  info "Add fixed number of redo logfiles and drop old ones"
    sqlplus -s / as sysdba << EOF
    whenever sqlerror exit failure
    set head off pages 1000 feed off termout off
    declare

      v_maxgroup_no          number;
      v_mingroup_no          number;
      v_active_group_count   number;
      v_current_group_no     number;

    begin

      select min(group#), max(group#) into v_mingroup_no, v_maxgroup_no from v\$log;

      for i in (v_maxgroup_no+1)..(v_maxgroup_no+4)
      loop
        execute immediate 'alter database add logfile group '||i||' size 1g';
      end loop;

      select group# into v_current_group_no from v\$log where status = 'CURRENT';
      while nvl(v_current_group_no,999999999) <= v_maxgroup_no
      loop
        begin
          dbms_lock.sleep(10);
          execute immediate 'alter system switch logfile';
          select group# into v_current_group_no from v\$log where status = 'CURRENT';
        exception
        when no_data_found
        then
          v_current_group_no:=null;
        end;
      end loop;

      execute immediate 'alter system checkpoint';

      select count(group#) into v_active_group_count from v\$log where status ='ACTIVE';
      while (v_active_group_count > 0)
      loop
        dbms_lock.sleep(30);
        begin
          select count(group#) into v_active_group_count from v\$log where status ='ACTIVE';
        end;
      end loop;

      for i in v_mingroup_no..v_maxgroup_no
      loop
        execute immediate 'alter database drop logfile group '||i;
      end loop;

    end;
    /
    exit
EOF
    [ $? -ne 0 ] && error "Adding and dropping redo logfiles"
}

# ------------------------------------------------------------------------------
# Create temp file, may differ depending on temporary tablespace name
# -------------------------------------------------------------------------------
create_tempfiles () {
  info "Create temp files and drop other tempfiles"
  sqlplus -s / as sysdba << EOF
  whenever sqlerror exit failure
  set head off pages 1000 feed off termout off
  declare
  cursor c1 is
    select 'alter tablespace '||ts.name||' add tempfile '||''''||'+DATA'||'''' cmd1,
            'alter tablespace '||ts.name||' drop tempfile '||''''||tf.name||'''' cmd2
   from v\$tablespace ts,
        v\$tempfile tf
   where ts.ts# = tf.ts#;
    sql_stmt varchar2(400);
  begin
    for r1 in c1
    loop
      sql_stmt := r1.cmd1;
      execute immediate sql_stmt;
      sql_stmt := r1.cmd2;
      execute immediate sql_stmt;
    end loop;
  end;
  /
  exit
EOF
  [ $? -ne 0 ] && error "Recreating temp files"
}

# ------------------------------------------------------------------------------
# Change database name and dbid
# ------------------------------------------------------------------------------
change_database_name () {
  info "Change database name and dbid"
    sqlplus / as sysdba << EOF
    alter user sys identified by sys;
    shutdown immediate
    startup mount exclusive pfile='${PFILE}'
    exit
EOF
  nid target=sys/sys dbname=${DBSID} logfile=${DBSID}_nid_change.log
  [ $? -ne 0 ] && error "Changing database name" || info "Changed database name"

  sed -e "s|^.*db_name.*|\*\.db_name='${DBSID}'|" ${PFILE} > ${PFILE}.bak
  mv  ${PFILE}.bak ${PFILE}
  info "Start with new database name"
  sqlplus / as sysdba << EOF
  startup mount pfile='${PFILE}'
  alter database open resetlogs;
EOF

  [ $? -ne 0 ] && error "Changing database name and dbid" || info "Changed datbase name and dbid"
}

# ------------------------------------------------------------------------------
# Add to CRS
# ------------------------------------------------------------------------------
add_to_crs () {
  info "Add database resource to CRS if not already"
    sqlplus -s / as sysdba <<EOF
    shutdown immediate
    exit
EOF
    srvctl status database -d ${DBSID} > /dev/null
    if [ $? -ne 0 ]
    then
      srvctl add database -d ${DBSID} -o ${ORACLE_HOME} -p +DATA/${DBSID}/spfile${DBSID}.ora -r PRIMARY -s OPEN -t IMMEDIATE -i ${DBSID} -n ${DBSID} -y AUTOMATIC -a "DATA,FLASH"
      [ $? -ne 0 ] && error "Adding database ${DBSID} to CRS"
    fi
    srvctl start database -d ${DBSID}
    [ $? -ne 0 ] && error "Starting ${DBSID} CRS resource"
}

# ------------------------------------------------------------------------------
# Create spfile and update pfile
# ------------------------------------------------------------------------------
add_spfile_asm () {

  info "Rename original ${SPFILE}"
  mv ${SPFILE} ${SPFILE}.bak
  info "Create spfile on ASM"
  dbsid=`echo "${DBSID}" | tr '[:upper:]' '[:lower:]'`
  sqlplus -s / as sysdba << EOF
   create spfile='+DATA/${DBSID}/spfile${DBSID}.ora' from pfile;
EOF
  [ $? -ne 0 ] && error "Creating spfile"
  info "Backup pfile and update to point to SPFILE in ASM"
  cp ${PFILE} ${PFILE}.bak
  echo "SPFILE='+DATA/${DBSID}/spfile${DBSID}.ora'" > ${PFILE}
}

# ------------------------------------------------------------------------------
# Catbundle PSU and OJVM postinstall
# ------------------------------------------------------------------------------
apply_psu_jvm_sql () {
 
  info "Apply catbundle PSU and OJVM postinstall, check apply_psu_ojvm.log for progress"
  set_ora_env ${DBSID}
  sqlplus -s / as sysdba << EOF >> apply_psu_ojvm.log
  @?/rdbms/admin/catbundle psu apply
  shutdown immediate
  startup upgrade
  @?/sqlpatch/27475598/postinstall.sql
  shutdown immediate
  startup
  @?/rdbms/admin/utlrp
  spool off
EOF
  [ $? -ne 0 ] && error "Applying psu and ojvm" || info "Completed"
}

reset_db_domain () {
  info "Reset db_name"
  sqlplus -s / as sysdba << EOF
  alter system set db_domain='' scope=spfile;
EOF
  srvctl stop database -d ${DBSID}
  srvctl start database -d ${DBSID}
  [ $? -ne 0 ] && error "Resetting db_name" || info "Completed"
}

restore_db_passwords () {

  info "Looking up passwords to in aws ssm parameter to restore by sourcing /etc/environment"
  . /etc/environment

  PRODUCT=`echo $HMPPS_ROLE`
  SYSTEMDBUSERS=(sys system dbsnmp)
  if [ "$PRODUCT" = "delius" ]
  then
    DBUSERS+=(delius_app_schema delius_pool )
  elif [ "$PRODUCT" = "mis" ]
  then
    DBUSERS+=(mis_landing ndmis_abc ndmis_cdc_subscriber ndmis_loader ndmis_working ndmis_data)
  fi

  info "Change password for all db users"
  DBUSERS+=( ${SYSTEMDBUSERS[@]} )
  for USER in ${DBUSERS[@]}
  do
    SUFFIX=${USER}_password
    for SYSTEMDBUSER in ${SYSTEMDBUSERS[@]}
    do
      if [ "${USER}" = "${SYSTEMDBUSER}" ]
      then
        SUFFIX=oradb_${USER}_password
        break
      fi
    done
    SSMNAME="/${HMPPS_ENVIRONMENT}/${APPLICATION}/${PRODUCT}-database/db/${SUFFIX}"
    USERPASS=`aws ssm get-parameters --region ${REGION} --with-decryption --name ${SSMNAME} | jq -r '.Parameters[].Value'`
    [ -z ${USERPASS} ] && error "Password for $USER in aws parameter store ${SSMNAME} does not exist"
    info "Change password for $USER"
    sqlplus -s / as sysdba << EOF
    alter user $USER identified by "${USERPASS}";
    exit
EOF
  done
}

post_actions () {
  if [ "$LEVEL" != "seed" ]
  then
    if [ "$FINAL" = "Y" -o "$LEVEL" = "cold" ]
    then
      disable_block_change_tracking
      rename_redologfiles
      add_drop_redologfiles
      create_tempfiles
      change_database_name
      add_spfile_asm
      add_to_crs
      apply_psu_jvm_sql
      restore_db_passwords
    fi
  else
    sqlplus -s / as sysdba <<EOF
    alter database open resetlogs;
    exit
EOF
    [ $? -ne 0 ] && error "Opening database"
    change_database_name
    add_spfile_asm
    add_to_crs
    restore_db_passwords
  fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
info "Start"

# ------------------------------------------------------------------------------
# Check that we have been given all the required arguments
# ------------------------------------------------------------------------------
info "Retrieving arguments"
[ -z "$1" ] && usage

DBSID=UNSPECIFIED
LEVEL=UNSPECIFIED
STAGINGDIR=UNSPECIFIED
FINAL=N
while getopts "t:l:d:f:" opt
do
  case $opt in
    t) DBSID=$OPTARG ;;
    l) LEVEL=$OPTARG ;;
    d) STAGINGDIR=$OPTARG ;;
    f) FINAL=$OPTARG ;;
    *) usage ;;
  esac
done
info "Oracle Sid = $DBSID"

# ------------------------------------------------------------------------------
# Validate parameters
# ------------------------------------------------------------------------------
validate_parameters

# ------------------------------------------------------------------------------
# Create logfile
# ------------------------------------------------------------------------------
LOGFILE=$STAGINGDIR/rmanrestore${LEVEL}_${TIMESTAMP}.log
exec > >(tee -ia ${LOGFILE})
exec 2> >(tee -ia ${LOGFILE} >&2)

# ------------------------------------------------------------------------------
# Pluck out information from the rman backup log files or s3 download backup pieces
# ------------------------------------------------------------------------------
if [ "$LEVEL" = "seed" ]
then
  download_seedbackup_from_s3
else
  check_rman_logfile
fi

# ------------------------------------------------------------------------------
# Remove existing database if exists
# ------------------------------------------------------------------------------
info "Source environment for $DBSID"
set_ora_env $DBSID > /dev/null
INITIALPFILE=$ORACLE_HOME/dbs/init${DBSID}_initial.ora
TEMPPFILE=$ORACLE_HOME/dbs/init.ora
PFILE=$ORACLE_HOME/dbs/init${DBSID}.ora
SPFILE=$ORACLE_HOME/dbs/spfile${DBSID}.ora

if [ "$LEVEL" = "0" -o "$LEVEL" = "cold" -o "$LEVEL" = "seed" ]
then
  info "Create audit directory, otherwise restore will fail"
  mkdir -p /u01/app/oracle/admin/${DBSID}/adump
  [ $? -ne 0 ] && error "Creating audit directory"

  info "Remove existing intialization files if exist for clean start"
  if [ -f $TEMPPFILE ]
  then
    rm $TEMPPFILE
  fi
  [ $? -ne 0 ] && error "Error removing $TEMPPFILE"
  if [ -f $PFILE ]
  then
    rm $PFILE
  fi
  [ $? -ne 0 ] && error "Error removing $PFILE"
  if [ -f $SPFILE ]
  then
    rm $SPFILE
  fi
  [ $? -ne 0 ] && error "Error removing $SPFILE"

  RUNNING=`ps -ef | grep ora_smon_$DBSID | grep -v grep | wc -l`
  if [ $RUNNING -eq 1 ]
  then
    info "Shutting down $DBSID"
    sqlplus -s / as sysdba <<EOF
    select sysdate from dual;
    shutdown abort;
EOF
  fi
  [ $? -ne 0 ] && error "Problem shutting down ${DBSID} instance"
  remove_directory DATA $DBSID
  remove_directory FLASH $DBSID
  asmcmd mkdir +DATA/${DBSID}
  set_ora_env $DBSID

  # ------------------------------------------------------------------------------
  # Create basic initialization variable and startup nomount
  # ------------------------------------------------------------------------------
  info "Creating basic initialization parameter"
  echo "db_name=$DBSID" > $INITIALPFILE
  info "Startup nomount with pfile='$INITIALPFILE'"
  sqlplus -s / as sysdba <<EOF
  startup nomount pfile='$INITIALPFILE'
EOF
  [ $? -ne 0 ] && error "Starting nomount"

  # ------------------------------------------------------------------------------
  # Restore spfile and copy oracle password file
  # ------------------------------------------------------------------------------
  info "Restore spfile from backup"
  echo "restore spfile from '$SPFILEPIECE';" > $STAGINGDIR/rmanrestorespfile.cmd
  rman target / cmdfile $STAGINGDIR/rmanrestorespfile.cmd log $STAGINGDIR/rmanrestorespfile.log > /dev/null
  [ $? -ne 0 ] && error "Restoring the spfile"

  cp $STAGINGDIR/orapw* $ORACLE_HOME/dbs/orapw${DBSID}
  [ $? -ne 0 ] && error "Copying oracle password file"

  # ------------------------------------------------------------------------------
  # Create pfile from newly created spfile, edit entries and startup
  # ------------------------------------------------------------------------------
  info "Create new pfile from spfile"
  sqlplus -s / as sysdba <<EOF
    create pfile from spfile='$ORACLE_HOME/dbs/spfile${DBSID}.ora';
    shutdown abort
    exit
EOF
  [ $? -ne 0 ] && error "Creating pfile from spfile and shutting down"

  [ ${#DATAFILEDIRECTORIES[@]} -gt 0 ] && SEPERATOR=","
  let i=0
  let j=0
  for DIRECTORY in ${DATAFILEDIRECTORIES[@]}
  do
    if [ $i -eq ${#DATAFILEDIRECTORIES[@]} ]
    then
      SEPERATOR=""
       j=1
    fi
    CONVERT="${CONVERT}'${DIRECTORY}','+DATA/${DBSID}' $SEPERATOR"
    [ $j -eq 1 ] && break
     i=`expr $i + 1`
  done

  info "Edit pfile"
  sed -e "s|^.*control.*|#&|"  \
      -e "s|^.*audit_file_dest.*|\*\.audit_file_dest='/u01/app/oracle/admin/${DBSID}/adump'|" \
      -e "s|^.*diagnostic_dest.*|\*\.diagnostic_dest='/u01/app/oracle'|" \
      -e "s|^.*db_recovery_file_dest.*|\*\.db_recovery_file_dest='+FLASH'|" \
      -e "/^.*log_archive_dest.*/d" \
      -e "$ a *.db_unique_name='${DBSID}'" \
      -e "$ a *.db_recovery_file_dest='+FLASH'" \
      -e "$ a *.db_create_file_dest='+DATA'" \
      -e "$ a *.db_create_online_log_dest_1='+DATA'" \
      -e "$ a *.db_create_online_log_dest_2='+FLASH'" \
      -e "$ a *.db_file_name_convert=${CONVERT}" \
      -e "$ a *.log_file_name_convert=${CONVERT}" \
      -e "$ a *.db_recovery_file_dest_size=50G" \
      -e "$ a *.log_archive_dest_1='LOCATION=use_db_recovery_file_dest VALID_FOR=(ONLINE_LOGFILES,ALL_ROLES)'" ${PFILE} > ${TEMPPFILE}

  info "Start $DBSID with amended temporary pfile"
   sqlplus -s / as sysdba << EOF
   startup nomount pfile='${TEMPPFILE}'
   exit;
EOF
  [ $? -ne 0 ] && error "Starting nomount"

  restore_controlfile
  restore_database

fi

[ "$LEVEL" = "1" ] && recover_database
[ "$LEVEL" != "0" ] && post_actions

info "End"
