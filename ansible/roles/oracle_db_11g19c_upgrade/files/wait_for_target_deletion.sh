#!/bin/bash


export TARGET_NAME=$1

# When we delete an OEM target it is done asynchronously but we cannot add a new target
# with the same name until this completes.   Loop for up to 5 minutes waiting for it
# to go away.  If it has not gone away after 5 minutes release the wait and try to add
# it anyway.
sqlplus -s /  as sysdba <<EOF
SET LINES 1000
SET PAGES 0
SET FEEDBACK OFF
SET HEADING OFF
SET TIMING ON
WHENEVER SQLERROR EXIT FAILURE
DECLARE
   l_target_still_exists INTEGER := 1;
   l_try_counter         INTEGER := 1;
BEGIN
   WHILE ((l_target_still_exists > 0) AND (l_try_counter<300))
   LOOP
      SELECT COUNT(*)
      INTO   l_target_still_exists
      FROM   sysman.mgmt_targets_delete
      WHERE  target_name = '${TARGET_NAME}'
      AND    delete_complete_time IS NULL
      AND    delete_request_time > SYSDATE-(1/24);
      l_try_counter := l_try_counter + 1;
      DBMS_LOCK.sleep(1);
   END LOOP;
END;
/
EXIT
EOF