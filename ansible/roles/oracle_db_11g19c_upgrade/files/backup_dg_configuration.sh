#!/bin/bash
# Backup existing Data Guard Configuration

TARGET_DIRECTORY=$1

BROKER_FILE1=$(
sqlplus -L -s /nolog <<EOSQL
connect / as sysdba
SET HEADING OFF
SELECT value
FROM   v\$parameter
WHERE  name = 'dg_broker_config_file1';
EOSQL
)

BROKER_FILE2=$(
sqlplus -L -s /nolog <<EOSQL
connect / as sysdba
SET HEADING OFF
SELECT value
FROM   v\$parameter
WHERE  name = 'dg_broker_config_file2';
EOSQL
)

export PATH=$PATH:/usr/local/bin; 
export ORACLE_SID=+ASM; 
export ORAENV_ASK=NO ; 
. oraenv >/dev/null;

asmcmd cp ${BROKER_FILE1} ${TARGET_DIRECTORY}

asmcmd cp ${BROKER_FILE2} ${TARGET_DIRECTORY}