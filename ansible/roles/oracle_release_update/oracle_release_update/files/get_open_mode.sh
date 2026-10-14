#!/bin/bash
# Get the Open Mode of the database

. ~/.bash_profile

sqlplus -s / as sysdba <<EOSQL
SET HEADING OFF
SELECT open_mode
FROM   v\$database;
EXIT
EOSQL
