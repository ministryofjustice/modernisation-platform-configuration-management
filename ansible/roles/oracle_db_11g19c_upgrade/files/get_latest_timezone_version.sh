#!/bin/bash

sqlplus -s / as sysdba <<EOSQL
SET HEADING OFF
SELECT DBMS_DST.get_latest_timezone_version
FROM   dual;
EXIT
EOSQL
