#!/bin/bash
# Check the Status of the Data Guard Broker

sqlplus -s / as sysdba <<EOSQL
SET HEADING OFF
SELECT value
FROM   v\$parameter
WHERE  name = 'dg_broker_start';
EXIT
EOSQL
