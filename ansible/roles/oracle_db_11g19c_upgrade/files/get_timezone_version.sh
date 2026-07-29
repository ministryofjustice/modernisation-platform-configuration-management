#!/bin/bash

sqlplus -s / as sysdba <<EOSQL
SET HEADING OFF
SELECT version
FROM   v\$timezone_file;
EXIT
EOSQL
