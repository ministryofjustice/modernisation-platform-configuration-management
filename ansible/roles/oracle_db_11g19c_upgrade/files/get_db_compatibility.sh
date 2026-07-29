#!/bin/bash
# Get the current database compatibility setting

sqlplus -s / as sysdba <<EOSQL
SET HEADING OFF
SELECT value
FROM   v\$parameter
WHERE  name='compatible';
EXIT
EOSQL
