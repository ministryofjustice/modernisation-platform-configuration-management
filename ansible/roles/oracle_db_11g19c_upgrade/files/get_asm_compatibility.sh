#!/bin/bash

export PATH=$PATH:/usr/local/bin; 
export ORACLE_SID=+ASM; 
export ORAENV_ASK=NO ; 
. oraenv >/dev/null;

sqlplus -s /  as sysasm <<EOF
SET LINES 1000
SET PAGES 0
SET FEEDBACK OFF
SET HEADING OFF
WHENEVER SQLERROR EXIT FAILURE
SELECT  'compatible.asm,'||name||','||compatibility
FROM    v\$asm_diskgroup
UNION ALL
SELECT  'compatible.rdbms,'||name||','||database_compatibility
FROM    v\$asm_diskgroup;
EXIT
EOF