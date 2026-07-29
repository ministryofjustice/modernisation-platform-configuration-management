#!/bin/bash
# Set the database compatibility setting


sqlplus -s / as sysdba <<EOSQL
SET HEADING OFF
ALTER SYSTEM SET compatible='19.0.0.0.0' SCOPE=SPFILE;
EXIT
EOSQL
