#!/bin/bash

sqlplus -s / as sysdba <<EOSQL
PURGE DBA_RECYCLEBIN;
-- Simply Purging the DBA recycle bin may not clear all objects.
-- See MoS 1910945.1
-- Will also truncate the underlying table to ensure
-- it has been cleared.
TRUNCATE TABLE sys.recyclebin$;
EXIT
EOSQL
