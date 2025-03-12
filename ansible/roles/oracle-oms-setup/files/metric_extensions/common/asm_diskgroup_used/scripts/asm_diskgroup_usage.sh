#!/bin/bash

. ~/.bash_profile

export ORAENV_ASK=NO
export ORACLE_SID=$(ps -ef | grep ora_smon | awk '{print $NF}' | cut -d_ -f3 | head -1)
. oraenv > /dev/null
sqlplus -S / as sysdba <<EOSQL
set heading off
set echo off
set feedback off
set pages 0
set lines 128
select name||'|'||round(total_mb/1024)||'|'||round(free_mb/1024)||'|'||round((total_mb-free_mb)/1024)
from v\$asm_diskgroup;
exit
EOSQL
