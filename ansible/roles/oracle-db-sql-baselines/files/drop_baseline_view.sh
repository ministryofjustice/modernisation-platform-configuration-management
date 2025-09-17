#!/bin/bash

. ~/.bash_profile

sqlplus  -s / as sysdba<<EOSQL
-- Drop baseline view if exists (ignore drop error)
BEGIN
  EXECUTE IMMEDIATE 'DROP VIEW delius_user_support.sql_plan_baseline_data';
EXCEPTION
  WHEN OTHERS THEN
    IF SQLCODE != -942 THEN
      RAISE;
    END IF;
END;
/
EXIT
EOSQL