#!/bin/bash

# We need to explicitly exclude the SYS.HIST_AUD$ table if it exists in this database
# because it is huge and gathering statistics on it will take many hours.

sqlplus -s / as sysdba <<EOSQL
WHENEVER SQLERROR EXIT FAILURE
DECLARE
   l_hist_aud_exists INTEGER;
BEGIN
   SELECT COUNT(*)
   INTO   l_hist_aud_exists
   FROM   user_tables
   WHERE  table_name = 'HIST_AUD$';
   IF l_hist_aud_exists != 0 THEN
      -- Temporarily disable statistics gathering on HIST_AUD$
      DBMS_STATS.LOCK_TABLE_STATS('SYS', 'HIST_AUD$');
   END IF;
END;
/
EXIT
EOSQL
