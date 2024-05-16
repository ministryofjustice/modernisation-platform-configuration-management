#!/bin/bash
# check mount is working by writing temporary file. Optionally update cloudwatch metric
FILESHARE_SOURCE="$1"
METRIC_NAME="$2"
METRIC_DIR="{{ filesystems_metric_dir }}"

if [[ -z $FILESHARE_SOURCE ]]; then
  echo "Usage: $0 <source> [<metric_name>]" >&2
  echo "Where" >&2
  echo "  <source>: fileshare source, e.g. first entry in fstab"
  echo "  <metric_name>: friendly name for file share for cloudwatch metric, no special chars or dashes"
  exit 1
fi

old_exitcode=""
if [[ -e "$METRIC_DIR/$METRIC_NAME.metric" ]]; then
  metrics=($(grep -E "^[[:alnum:][:punct:]]+[[:space:]]+[[:digit:]]+" "$METRIC_DIR/$METRIC_NAME.metric" | grep -v ^#))
  old_exitcode=${metrics[1]}
fi

mount_dir=$(mount | grep -Fw "$FILESHARE_SOURCE" | cut -d\  -f3)
if [[ -z $mount_dir ]]; then
  exitcode=1
else
  timeout 5 echo test > "$mount_dir/${HOSTNAME}_keepalive.txt"
  exitcode=$?
fi

if [[ -n $METRIC_NAME ]]; then
  echo "$METRIC_NAME $exitcode" > "$METRIC_DIR/$METRIC_NAME.metric"
fi
if [[ -z $old_exitcode || $exitcode -ne $old_exitcode ]]; then
  if [[ $exitcode -eq 0 ]]; then
    echo "$FILESHARE_SOURCE: mounted ok, updated ${HOSTNAME}_keepalive.txt"
  else
    echo "$FILESHARE_SOURCE: error writing keepalive $exitcode"
  fi
fi
exit $exitcode
