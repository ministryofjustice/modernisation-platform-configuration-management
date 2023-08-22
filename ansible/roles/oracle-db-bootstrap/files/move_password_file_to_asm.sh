#!/bin/bash

. ~/.bash_profile

export DBUNIQUENAME=${ORACLE_SID}
export SOURCE_PASSWORD_FILE=${ORACLE_HOME}/dbs/orapw${DBUNIQUENAME}

export ORACLE_SID=+ASM; 
export ORAENV_ASK=NO ; 
. oraenv

asmcmd <<EOASMCMD
pwmove --dbuniquename ${DBUNIQUENAME} ${SOURCE_PASSWORD_FILE} +DATA/${DBUNIQUENAME}/orapw${DBUNIQUENAME}
EOASMCMD
