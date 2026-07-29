#!/bin/bash


DB_ROLE=$(sqlplus -s / as sysdba <<EOF
set heading off feedback off verify off pages 0 echo off
SELECT database_role FROM v\$database;
exit
EOF
)

# Clean whitespace
DB_ROLE=$(echo "$DB_ROLE" | xargs)

# Output for Ansible
echo "$DB_ROLE"



