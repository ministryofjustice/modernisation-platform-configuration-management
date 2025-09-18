#!/bin/bash

. ~/.bash_profile
export PATH=$PATH:/usr/local/bin
. oraenv <<< ${TARGET_DB_NAME}

# SQL to create directory and external table
sqlplus -s / as sysdba<<EOF
WHENEVER SQLERROR EXIT FAILURE
DROP DIRECTORY sql_plan_baseline_data_dir;
EXIT
EOF