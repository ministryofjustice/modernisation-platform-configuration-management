#!/bin/bash

# Get the number of processors available for running the upgrade
# PROCESSORS=$(cat /proc/cpuinfo  | grep processor | wc -l)

#Cap the number of processes at 8 according to maximum allowed by Oracle
# PARALLELISM=$(( PROCESSORS > 8 ? 8 : PROCESSORS ))

# echo "Using $PARALLELISM processors"

# Run the Oracle upgrade
# $ORACLE_HOME/bin/dbupgrade -n ${PARALLELISM} -l ${ORACLE_BASE}/admin/${ORACLE_SID}/upgrade
$ORACLE_HOME/bin/dbupgrade -l ${ORACLE_BASE}/admin/${ORACLE_SID}/upgrade