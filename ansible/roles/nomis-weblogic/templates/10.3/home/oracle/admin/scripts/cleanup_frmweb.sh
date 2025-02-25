#!/bin/bash
PIDS=$(ps -C frmweb -o %p, -o %u, -o %t, -o %c, -o %C | tr -d " " | egrep ",[0-9]+-[0-9]+:[0-9]+:[0-9]+," | cut -d, -f1 | sort -ug | tr [:space:] " " | sed "s/ $//")
if [[ -n $PIDS ]]; then
  echo "Killing frmweb processes older than 24 hours: ${PIDS// /,}"
  ps -q ${PIDS// /,} ux
  kill -9 $PIDS
fi

PIDS=$(/usr/sbin/lsof | grep deleted | grep frmweb | gawk '{print $2}' | sort -ug | tr [:space:] " " | sed "s/ $//")
if [[ -n $PIDS ]]; then
  echo "Checking frmweb processes with deleted lsof: ${PIDS// /,}"

  # 10 hours
  PIDS2=$(ps -q ${PIDS// /,} -o %p, -o %u, -o %t, -o %c, -o %C | tr -d " " | egrep ",1[0-9]:[0-9]+:[0-9]+," | cut -d, -f1 | sort -ug | tr [:space:] " " | sed "s/ $//")
  if [[ -n $PIDS2 ]]; then
    echo "Killing frmweb processes with deleted lsof older than 10 hours: ${PIDS2// /,}"
    ps -q ${PIDS2// /,} ux
    kill -9 $PIDS2
  fi

  # 2 hours (disabled as this appears to kill active nomis sessions prematurely)
  # PIDS2=$(ps -q ${PIDS// /,} -o %p, -o %u, -o %t, -o %c, -o %C | tr -d " " | egrep ",1[0-9]:[0-9]+:[0-9]+,|0[2-9]:[0-9]+:[0-9]+," | cut -d, -f1 | sort -ug | tr [:space:] " " | sed "s/ $//")
  # if [[ -n $PIDS2 ]]; then
  #   echo "Killing frmweb processes with deleted lsof older than 2 hours: ${PIDS2// /,}"
  #   ps -q ${PIDS2// /,} ux
  #   kill -9 $PIDS2
  # fi
fi

PIDS=$(/usr/sbin/lsof | grep deleted | grep frmweb | gawk '{print $2,$7}'  | sort -ug | grep -E "^[0-9]+ [0-9]{10}" | cut -d\  -f1 | tr [:space:] " " | sed "s/ $//")
if [[ -n $PIDS ]]; then
  echo "Killing frmweb processes with deleted lsof files bigger than 1GB: ${PIDS// /,}"
  ps -q ${PIDS// /,} ux
  kill -9 $PIDS
fi
