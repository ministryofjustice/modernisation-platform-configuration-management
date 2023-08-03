#!/bin/bash

THISSCRIPT=`basename $0`

info () {
  T=`date +"%D %T"`
  echo -e "INFO : $THISSCRIPT : $T : $1"
}

error () {
  T=`date +"%D %T"`
  echo -e "ERROR : $THISSCRIPT : $T : $1"
  exit 1
}

usage () {
  echo ""
  echo "Usage:"
  echo ""
  echo "  $THISSCRIPT -d <target db sid> -l <local backup dir > -p <src backup sys password> -s <s3 src backup dir> -a <action>"
  echo ""
  echo "  action                  = function name to run (all runs all)"
  echo "  target db sid           = sid of database to be restored to"
  echo "  local backup dir        = location where back will be copied to"
  echo "  src backup sys password = password of the source db backup sys"
  echo "  s3 src backup dir       = full s3 path to backup file in S3 bucket"
  echo ""
  exit 1
}

check_vgsize () {
  ORACLE_SID=+ASM
  . oraenv
  info "`asmcmd lsdg --suppressheader DATA | awk '{printf ("Disk group DATA FreeMb: %s\n", $8)}'`"
  info "`asmcmd lsdg --suppressheader FLASH  | awk '{printf ("Disk group FLASH FreeMb: %s\n", $8)}'`"
}

remove_directory () {
  VG=$1
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

download_coldbackup_from_s3() {
  # ------------------------------------------------------------------------------
  # Download cold backup pieces from relevant S3 bucket directory
  # ------------------------------------------------------------------------------
  echo "aws s3 sync ${SRC_S3_BACKUP_PATH} ${BACKUP_LOCATION}"
  aws s3 ls ${SRC_S3_BACKUP_PATH}
  [ $? -ne 0 ] && error "Backup not on S3 bucket"

  aws s3 sync ${SRC_S3_BACKUP_PATH} ${BACKUP_LOCATION} --exclude "*" --include "cold*"
  [ $? -ne 0 ] && error "Unable to download cold backup pieces from S3 bucket"

  exit 0
}

restore() {
  # ------------------------------------------------------------------------------
  # Create pfile from current spfile
  # ------------------------------------------------------------------------------
  ORAENV_ASK=NO
  ORACLE_SID=$TARGETDB
  . oraenv
  PFILETMP="$ORACLE_HOME/dbs/tmp.ora"
  PFILESOURCEDB="$ORACLE_HOME/dbs/tmp1.ora"
  PFILECONTROL="$ORACLE_HOME/dbs/tmp2.ora"
  info "Create temporary initialization file from existing spfile"
  if [ ! -f $PFILETMP ]
  then
    sqlplus / as sysdba << EOF
    create pfile='$PFILETMP' from spfile;
    exit;
EOF
  fi
  [ $? -ne 0 ] && error "Creating temporary initialization file"

  # ------------------------------------------------------------------------------
  # Find source db name from rman backup file and edit temp init file
  # ------------------------------------------------------------------------------
  info "Find source db_name from controlfile rman backup piece"
  CONTROL_BACKUP=`ls -1 $BACKUP_LOCATION/cold_control*`
  # Source DB SID retrieved from file
  SOURCEDB=`echo $CONTROL_BACKUP | awk -F'_' '{print $4}'`
  [ -z $SOURCEDB ] && error "No source database found" ]
  info "Source db is $SOURCEDB"
  info "Replace db_name with $SOURCEDB and add db_unique_name"
  sed -e "s|.*db_name.*|\*\.db_name='$SOURCEDB'|" \
      -e "$ a *.db_unique_name='$TARGETDB'" $PFILETMP > $PFILESOURCEDB

  # ------------------------------------------------------------------------------
  # Remove existing asm directories
  # ------------------------------------------------------------------------------
  database_operation stop
  check_vgsize
  remove_directory DATA
  remove_directory FLASH
  check_vgsize

  # ------------------------------------------------------------------------------
  # Restore controlfile
  # ------------------------------------------------------------------------------
  info "Restore controlfile from backup"
  ORACLE_SID=$TARGETDB
  . oraenv
  rman target / << EOF
  run
  {
    startup nomount pfile='$PFILESOURCEDB';
    set controlfile autobackup format for device type disk to '%F';
    restore controlfile from '$CONTROL_BACKUP';
  }
EOF
  [ $? -ne 0 ] && error "Restoring controlfile"

  # ------------------------------------------------------------------------------
  # Capture the new control file names and replace in temp init file
  # ------------------------------------------------------------------------------
  info "Find new controlfile names"
  ORACLE_SID=+ASM
  . oraenv
  CONTROLFILE1=`asmcmd ls +DATA/$TARGETDB/CONTROLFILE`
  CONTROLFILE2=`asmcmd ls +FLASH/$TARGETDB/CONTROLFILE`
  CONTROLPATH1="+DATA/$TARGETDB/CONTROLFILE/$CONTROLFILE1"
  CONTROLPATH2="+FLASH/$TARGETDB/CONTROLFILE/$CONTROLFILE2"
  info "Control file 1: $CONTROLPATH1"
  info "Control file 2: $CONTROLPATH2"
  info "Replace controlfile in $PFILECONTROL with new controlfiles"
  sed -e "s|.*control.*|\*\.control_files='$CONTROLPATH1','$CONTROLPATH2'|" $PFILESOURCEDB > $PFILECONTROL

  # ------------------------------------------------------------------------------
  # Startup mount with temp init file
  # ------------------------------------------------------------------------------
  info "Starting with temp init file $PFILECONTROL"
  ORACLE_SID=$TARGETDB
  . oraenv
  sqlplus / as sysdba << EOF
    shutdown abort;
    startup mount pfile='$PFILECONTROL';
EOF

  # ------------------------------------------------------------------------------
  # Restore database
  # ------------------------------------------------------------------------------
  info "Restore database from backup"
  rman target / << EOF
  run
  {
    allocate channel ch1 device type disk;
    allocate channel ch2 device type disk;
    crosscheck backup;
    delete noprompt expired backup;
    restore database from tag='DB_COLD';
    sql 'alter database open resetlogs';
    release channel ch1;
    release channel ch2;
  }
EOF
  [ $? -ne 0 ] && error "Restoring database" || info "Database restored"

  # ------------------------------------------------------------------------------
  # Change dbid and db_name using nid utility
  # ------------------------------------------------------------------------------
  info "Changing dbid and db_name"
  sqlplus / as sysdba << EOF
    shutdown immediate;
    startup mount exclusive pfile='$PFILECONTROL';
    exit;
EOF
  nid target=sys/$SYSPASSWORD dbname=$TARGETDB logfile=nid.log
  [ $? -ne 0 ] && error "Investigate issue with nid"

  # ------------------------------------------------------------------------------
  # Create final pfile with target db_name
  # ------------------------------------------------------------------------------
  info "Replace db_name in $PFILETMP with target db name"
  sed -e "s|.*db_name.*|\*\.db_name='$TARGETDB'|" $PFILECONTROL > $PFILETMP

  info "Create spfile in +DATA from $PFILETMP"
  ORACLE_SID=$TARGETDB
  . oraenv
  sqlplus / as sysdba << EOF
    startup mount pfile='$PFILETMP';
    create spfile='+DATA/${TARGETDB}/spfile${TARGETDB}.ora' from pfile='$PFILETMP';
    alter database open resetlogs;
    exit;
EOF

  info "Reference target spfile in original pfile"
  echo "'SPFILE='+DATA/${TARGETDB}/spfile${TARGETDB}.ora'" > $ORACLE_HOME/dbs/init${TARGETDB}

  info "Start database with srvctl utility ie. spfile"
  database_operation stop
  database_operation start
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------
LOGFILE="${HOME}/$(date +%Y%m%d_%H%M%S)_${THISSCRIPT}.log"
exec >  >(tee -ia ${LOGFILE})
exec 2> >(tee -ia ${LOGFILE} >&2)


info "Start"

# ------------------------------------------------------------------------------
# Check that we are running as the correct user (oracle)
# ------------------------------------------------------------------------------
info "Validating user"
THISUSER=`id | cut -d\( -f2 | cut -d\) -f1`
[ "$THISUSER" != "oracle" ] && error "Must be oracle to run this script"
info "User ok"

# ------------------------------------------------------------------------------
# Check that we have been given all the required arguments
# ------------------------------------------------------------------------------
info "Retrieving arguments"
[ -z "$1" ] && usage

TARGETDB=UNSPECIFIED

while getopts "a:d:l:p:s:" opt
do
  case $opt in
    a) ACTION=$OPTARG ;;
    d) TARGETDB=$OPTARG ;;
    l) BACKUP_LOCATION=$OPTARG ;;
    p) SYSPASSWORD=$OPTARG ;;
    s) SRC_S3_BACKUP_PATH=$OPTARG ;;
    *) usage ;;
  esac
done
info "Target SID     = $TARGETDB"
info "Backup dir     = $BACKUP_LOCATION"
info "Sys passwd     = [REDACTED]"
info "S3 URL         = $SRC_S3_BACKUP_PATH"
info "ACTION         = $ACTION"

# ------------------------------------------------------------------------------
# Check parameters
# ------------------------------------------------------------------------------
[ -z "$1" ] && usage



case ${ACTION} in
  # ------------------------------------------------------------------------------
  # Download cold backup pieces from relevant S3 bucket directory
  # ------------------------------------------------------------------------------
  download)
    info "Validating backup dir"
    [ -z "$BACKUP_LOCATION" -o "$BACKUP_LOCATION" = "unspecified" ] && error "BACKUP_LOCATION parameter incorrect"
    info "Validating S3 Path value"
    [ -z "$SRC_S3_BACKUP_PATH" -o "$SRC_S3_BACKUP_PATH" = "unspecified" ] && error "S3 path parameter incorrect"
    download_coldbackup_from_s3
    exit 0
  ;;

  restore)
    info "Validating target database"
    [ -z "$TARGETDB" -o "$TARGETDB" = "UNSPECIFIED" ] && error "Target db parameter incorrect"
    grep ^${TARGETDB}: /etc/oratab >/dev/null 2>&1
    [ $? -ne 0 ] && error "Database $TARGETDB does not exist on this machine"
    info "Target database ok"
    info "Validating backup dir"
    [ -z "$BACKUP_LOCATION" -o "$BACKUP_LOCATION" = "unspecified" ] && error "BACKUP_LOCATION parameter incorrect"
    info "Validating sys password"
    [ -z "$SYSPASSWORD" -o "$SYSPASSWORD" = "unspecified" ] && error "SYSPASSWORD parameter incorrect"

    . ${HOME}/.bash_profile
    restore
    exit 0
  ;;

  *)
    error "${ACTION} is not a valid argument."
  ;;
esac
