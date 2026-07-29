#!/bin/bash

# Prepare for Updating the Timezone File

TIMEZONE_VERSION=$1

sqlplus -s / as sysdba <<EOSQL

WHENEVER SQLERROR EXIT FAILURE;

DECLARE
  l_upgrade_state  VARCHAR2(4000);
BEGIN
   -- Get existing Upgrade state
   SELECT property_value
   INTO   l_upgrade_state
   FROM   database_properties
   WHERE  property_name = 'DST_UPGRADE_STATE';

   -- End any pre-existing Prepare State
   IF l_upgrade_state = 'PREPARE' THEN
      DBMS_DST.end_prepare;
   END IF;

   -- Start new Prepare State
   DBMS_DST.begin_prepare(${TIMEZONE_VERSION});
END;
/

TRUNCATE TABLE sys.dst\$affected_tables;
TRUNCATE TABLE sys.dst\$error_table;

BEGIN
   DBMS_DST.find_affected_tables;
END;
/

DECLARE
   l_errors INTEGER;
BEGIN

   SELECT COUNT(*)
   INTO   l_errors
   FROM   sys.dst\$error_table;

   DBMS_DST.end_prepare;

   IF l_errors > 0 THEN
      RAISE_APPLICATION_ERROR(-20001,'Errors detected preparing for timezone update.');
   END IF;

END;
/

EXIT
EOSQL
