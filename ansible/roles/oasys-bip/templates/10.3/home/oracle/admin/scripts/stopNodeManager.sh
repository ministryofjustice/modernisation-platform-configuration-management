#!/bin/bash
set -x
# Get details of nodemanager processes

process_pids1=$(pgrep -u oracle -f "startNodeManager.sh$" 2> /dev/null)
process_pids2=$(pgrep -u oracle -f "weblogic.NodeManager" 2> /dev/null)

kill -9 $process_pids1 $process_pids2 2> /dev/null
