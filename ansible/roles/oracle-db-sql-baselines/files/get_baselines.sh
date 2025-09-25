#!/bin/bash
#
#  Get a list of existing SQL Plan Baselines
#

. ~/.bash_profile
export PATH=$PATH:/usr/local/bin
export ORAENV_ASK=NO
export ORACLE_SID=${TARGET_DB_NAME}
. oraenv -s

sqlplus  -s / as sysdba<<EOSQL
SET PAGES 0
SET FEEDBACK OFF
SELECT DISTINCT sql_handle
FROM   dba_sql_plan_baselines;
EXIT
EOSQL