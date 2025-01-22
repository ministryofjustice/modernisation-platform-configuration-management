#!/bin/bash
# Managed in code modernisation-platform-configuration-management repo, sap-bip-4 role
# This script stops SAP processes (Tomcat/CCM), archives logs, and then restarts SAP processes

BOBJEDIR="{{ sap_bip_installation_directory }}/sap_bobj"
BOBJUSER="bobj"
CURRENTUSER=$(whoami)
DRYRUN=${DRYRUN:-0}

stop_processes() {
  if [ -f "$BOBJEDIR"/ccm.config ]; then
    if [[ $DRYRUN != 0 ]]; then
      echo "DRYRUN: Stopping servers"
    else
      "$BOBJEDIR"/ccm.sh -stop all
      logger -p daemon.info -t bobj "Stopped servers"
    fi
  fi
  if [ -d "$BOBJEDIR"/tomcat ]; then
    if [[ $DRYRUN != 0 ]]; then
      echo "DRYRUN: Stopping Tomcat"
    else
      "$BOBJEDIR"/tomcatshutdown.sh
      logger -p daemon.info -t bobj "Stopped Tomcat"
    fi
  fi
}

archive_logs() {
  if [[ -x /home/$BOBJUSER/archive_logs.sh ]]; then
    if [[ $DRYRUN != 0 ]]; then
      DRYRUN=$DRYRUN /home/$BOBJUSER/archive_logs.sh
    else
      echo "Archiving Logs"
      /home/$BOBJUSER/archive_logs.sh | logger -p daemon.info -t bobj
    fi
  fi
}

start_processes() {
  if [ -d "$BOBJEDIR"/tomcat ]; then
    if [[ $DRYRUN != 0 ]]; then
      echo "DRYRUN: Starting Tomcat"
    else
      "$BOBJEDIR"/tomcatstartup.sh
      logger -p daemon.info -t bobj "Started Tomcat"
    fi
  fi
  if [ -f "$BOBJEDIR"/ccm.config ]; then
    if [[ $DRYRUN != 0 ]]; then
      echo "DRYRUN: Starting servers"
    else
      "$BOBJEDIR"/ccm.sh -start all
      logger -p daemon.info -t bobj "Started servers"
    fi
  fi
}

if [[ "$BOBJUSER" != "$CURRENTUSER" ]]; then
  echo "ERROR: This script must be run as $BOBJUSER"
  [[ $DRYRUN == 0 ]] && exit 1
fi

if pgrep -u bobj java > /dev/null; then
  stop_processes
fi
archive_logs
start_processes
