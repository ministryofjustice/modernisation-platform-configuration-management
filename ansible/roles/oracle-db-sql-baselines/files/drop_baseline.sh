#!/bin/bash
#
#  Drop a SQL Plan Baseline 
#  (including all plans)
#

SQL_HANDLE=$1

. ~/.bash_profile
export PATH=$PATH:/usr/local/bin
. oraenv <<< ${TARGET_DB_NAME}

sqlplus  -s / as sysdba<<EOSQL
WHENEVER SQLERROR EXIT FAILURE
SET PAGES 0
SET FEEDBACK OFF
DECLARE
   x INTEGER;
BEGIN
   x := DBMS_SPM.drop_sql_plan_baseline (sql_handle => '${SQL_HANDLE}');
END;
/
EXIT
EOSQL