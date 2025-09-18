#!/bin/bash

. ~/.bash_profile
export PATH=$PATH:/usr/local/bin
. oraenv <<< ${TARGET_DB_NAME}

sqlplus  -s / as sysdba<<EOSQL
-- Drop baseline view if exists (ignore drop error)
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW ${DBA_OPS_SCHEMA}.sql_plan_baseline_data';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
      RAISE;
    END IF;
END;
/
EXIT
EOSQL