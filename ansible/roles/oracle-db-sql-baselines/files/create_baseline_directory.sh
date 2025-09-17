#!/bin/bash

JSON_DIR_PATH=$1

. ~/.bash_profile

# SQL to create directory and external table
sqlplus -s / as sysdba<<EOF
WHENEVER SQLERROR EXIT FAILURE
CREATE OR REPLACE DIRECTORY sql_plan_baseline_data_dir AS '${JSON_DIR_PATH}';
EXIT
EOF