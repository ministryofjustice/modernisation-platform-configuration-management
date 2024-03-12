#!/bin/bash

PARENT_IDS=$(ps -ef | grep ssm-session-worker | grep -v grep | awk '{print $2}' | paste -sd "|")

# Find Defunct ssm-session-worker processes
DEFUNCT_COUNT=$(ps -ef | egrep -e "(${PARENT_IDS:-NONEFOUND})" | grep -c "<defunct>")

# Find ssm-user sh processes running for over a day
LONG_RUNNING_SH_COUNT=$(ps -e -o user,cmd,etimes=  | grep ssm-user | grep -E "[[:space:]]sh[[:space:]]"|  awk '{if($3>86400){print $0}}' | wc -l)

# Find ssm-session-worker processes running for over a day
LONG_RUNNING_SSM_COUNT=$(ps -e -o user,cmd,etimes=  | grep root | grep -E "[[:space:]]/usr/bin/ssm-session-worker[[:space:]]"|  awk '{if($3>86400){print $0}}' | wc -l)

echo "$DEFUNCT_COUNT|$LONG_RUNNING_SH_COUNT|$LONG_RUNNING_SSM_COUNT"