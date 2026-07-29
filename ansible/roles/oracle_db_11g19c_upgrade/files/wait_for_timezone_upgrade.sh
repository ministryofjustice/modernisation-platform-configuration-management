#!/bin/bash

# Wait for Timezone Upgrade to complete

sqlplus -s / as sysdba <<EOSQL
SET LINES 1000
SET PAGES 0
SET FEEDBACK OFF
SET HEADING OFF
SET TIMING ON
WHENEVER SQLERROR EXIT FAILURE
DECLARE
   l_upgrade_in_progress INTEGER := 1;
   l_try_counter         INTEGER := 1;
BEGIN
   WHILE ((l_upgrade_in_progress > 0) AND (l_try_counter<1800))
   LOOP
      SELECT COUNT(*)
      INTO   l_upgrade_in_progress
      FROM   dba_tstz_tables
      WHERE  upgrade_in_progress = 'YES';
      l_try_counter := l_try_counter + 1;
      DBMS_LOCK.sleep(1);
   END LOOP;
   IF l_upgrade_in_progress > 0 THEN
      RAISE_APPLICATION_ERROR(-20005,'Timezone version upgrade timed out');
   END IF;
END;
/
EXIT
EOSQL
