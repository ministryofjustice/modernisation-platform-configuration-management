#!/bin/bash

. ~/.bash_profile

# SQL to create directory and external table
sqlplus -s / as sysdba<<EOF
DROP DIRECTORY sql_plan_baseline_data_dir'';
EXIT
EOF