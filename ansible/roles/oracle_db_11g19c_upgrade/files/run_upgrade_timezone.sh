#!/bin/bash

# Run Upgrade of Timezone File

sqlplus -s / as sysdba <<EOSQL

WHENEVER SQLERROR EXIT FAILURE;

DECLARE
  l_failures   PLS_INTEGER;
BEGIN
  DBMS_DST.upgrade_database(l_failures);
  IF l_failures > 0 THEN
     RAISE_APPLICATION_ERROR(-20002,'DBMS_DST.upgrade_database : l_failures=' || l_failures);
  END IF;
  DBMS_DST.end_upgrade(l_failures);
  IF l_failures > 0 THEN
     RAISE_APPLICATION_ERROR(-20003,'DBMS_DST.end_upgrade : l_failures=' || l_failures);
  END IF;

  -- Update the Registry
  -- See MOS Doc ID 1255474.1
  UPDATE registry\$database 
  SET    tz_version = (SELECT version 
                       FROM   v\$timezone_file);

END;
/

COMMIT;

EXIT
EOSQL
