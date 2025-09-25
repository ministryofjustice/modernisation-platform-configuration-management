#!/bin/bash
#
#  Non-impacting Query to test Connectivity only

. ~/.bash_profile
export PATH=$PATH:/usr/local/bin
export ORAENV_ASK=NO
export ORACLE_SID=${TARGET_DB_NAME}
. oraenv -s

sqlplus  -s / as sysdba<<EOSQL
SET PAGES 0
SET FEEDBACK OFF
SELECT name
FROM   v\$database;
EXIT
EOSQL