#!/bin/bash
#
# Return the total SGA size in KB for the target database.
# Output is a single integer value on stdout.
#

. ~/.bash_profile
export PATH=$PATH:/usr/local/bin
export ORAENV_ASK=NO
export ORACLE_SID=${TARGET_DB_NAME}
. oraenv -s

sqlplus -s / as sysdba <<EOSQL
SET PAGES 0
SET FEEDBACK OFF
SET HEADING OFF
WHENEVER SQLERROR EXIT FAILURE

SELECT ROUND(SUM(value)/1024) FROM v\$sga;
EXIT
EOSQL
