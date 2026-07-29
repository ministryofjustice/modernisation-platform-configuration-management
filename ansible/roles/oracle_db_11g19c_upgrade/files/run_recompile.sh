#!/bin/bash


sqlplus -s / as sysdba <<EOSQL
@?/rdbms/admin/utlprp 0
-- Now report any invalid SYS and SYSTEM objects
SET LINES 128
SET SERVEROUT ON
SET HEADING OFF
SELECT 'INVALID='||COUNT(*)
FROM   dba_objects
WHERE  owner IN ('SYS','SYSTEM')
AND    status != 'VALID';
EXIT
EOSQL
