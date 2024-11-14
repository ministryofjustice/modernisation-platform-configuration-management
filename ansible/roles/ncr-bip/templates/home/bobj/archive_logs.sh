#!/bin/bash
# Managed in code modernisation-platform-configuration-management repo, ncr-bip role
# To dryrun, run like this: DRYRUN=1 ./archive-logs.sh 

BOBJEDIR="{{ sap_bip_installation_directory }}/sap_bobj"
BOBJUSER="bobj"
CURRENTUSER=$(whoami)
DATESTAMP=$(date +%Y%m%d_%H%M)
ARCHLOGDIR="{{ sap_bip_archived_logs_directory }}/Archived_Logs_${DATESTAMP}"
DRYRUN=${DRYRUN:-0}

if [[ "$BOBJUSER" != "$CURRENTUSER" ]]; then
  echo "ERROR: This script must be run as $BOBJUSER"
  [[ $DRYRUN == 0 ]] && exit 1
fi

if pgrep -u bobj java > /dev/null; then
  echo "ERROR: Please stop bobj processes before running"
  [[ $DRYRUN == 0 ]] && exit 1
fi

mv_files() {
  files=$(find "$1" -name "$2" 2>/dev/null)
  if [[ -n $files ]]; then
    if [[ ! -d $ARCHLOGDIR ]]; then
      echo "Creating log file archive $ARCHLOGDIR"
      [[ $DRYRUN == 0 ]] && mkdir -p "$ARCHLOGDIR"
    fi
    num_files=$(wc -l <<< "$files")
    echo "Moving $num_files files from $1/$2 to $ARCHLOGDIR/"
    [[ $DRYRUN == 0 ]] && mv "$1/"$2 "$ARCHLOGDIR/"
  fi
}

mv_files "$BOBJEDIR/logging" "*.*"
mv_files "$BOBJEDIR/tomcat/logs" "*.*"
mv_files "$BOBJEDIR/tomcat/bin" "TraceLog_*"
mv_files ~ "SBOPWebapp_*"
