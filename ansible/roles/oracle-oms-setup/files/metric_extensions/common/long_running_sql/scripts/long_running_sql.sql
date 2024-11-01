#!/bin/bash
#
#  Get active user sessions
#

. ~/.bash_profile

# Exit without failure if database is not up
srvctl status database -d $ORACLE_SID >/dev/null || exit 0

sqlplus -s / as sysdba <<EOSQL
SET ECHO OFF
SET FEEDBACK OFF
SET HEAD OFF
SET PAGES 0
select NVL(MAX(last_call_et),0) max_last_call_et
from v\$session
where type='USER'
and status='ACTIVE'
and (action != 'PRF_COLL_JOB' OR action IS NULL)
and (NOT program LIKE '%rman@%' OR program IS NULL)
and (NOT program LIKE '%(PR__)' OR program IS NULL)
;
EXIT
EOSQL