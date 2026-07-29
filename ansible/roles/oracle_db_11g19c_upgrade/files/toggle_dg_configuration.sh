#!/bin/bash
# Disable or Enable existing Data Guard Configuration
DGSTATUS=$1

dgmgrl <<EDGMGR
connect /
${DGSTATUS} configuration;
EDGMGR

