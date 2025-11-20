#!/usr/bin/env bash

LOG=/tmp/rsyslog_management_pack_access.log

date +"%F %T started" >>  $LOG

process_line() {
    # Replace this with your actual processing logic
    echo "$(date) Processing: $1" >> $LOG
    /home/oracle/admin/em/set_management_packs.sh >> $LOG 2>&1
    echo OK
}

last_line=""
while IFS= read -r line; do
    last_line="$line"
    echo "$(date) *** INPUT ***" >> $LOG

    # Wait briefly to see if more input arrives
    while read -t 3 -r next_line; do
        last_line="$next_line"
    done

    # No more lines after the pause → process the last one
    process_line "$last_line"
done

exit 0