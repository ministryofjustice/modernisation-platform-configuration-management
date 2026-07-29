#!/bin/bash

# Expression Filter (EXF) or Rules Manager (RUL) exist in the database.    
# Starting with Oracle Database release 12.1, the Expression Filter (EXF)
# and Database Rules Manager (RUL) features are desupported, and are
# removed during the upgrade process.  This step can be manually performed
# before the upgrade to reduce downtime.
# located in the new Oracle Database Oracle home to remove both EXF and RUL.
# Run $ORACLE_HOME/rdbms/admin/catnoexf.sql located in the new Oracle
#      Database Oracle home to remove both EXF and RUL.

sqlplus -s / as sysdba <<EOSQL

WHENEVER SQLERROR EXIT FAILURE

@/u01/app/oracle/product/19c/db_1/rdbms/admin/catnoexf.sql

EXIT

EOSQL
