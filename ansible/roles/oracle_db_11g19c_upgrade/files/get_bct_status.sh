#!/bin/bash
# Check the Status of Block Change Tracking

sqlplus -s / as sysdba <<EOSQL
SET HEADING OFF
SELECT status
FROM   v\$block_change_tracking;
EXIT
EOSQL
