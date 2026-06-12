#!/bin/bash
#
# This metric extension is only intended for Delius.   It is intended to raise an alert if there
# is a non-zero number of entries in the R_SERVICE_USER table which do not map to a USER_.
#
# The R_SERVICE_USER table is used to identify which Integration Service is adding or updating a
# row and uses the Oracle database username as the source of this identity.  R_SERVICE_USER is
# intended to map this Oracle database username to a Delius user.  However we allow missing
# mappings (USER_ is null) to avoid services failing if the Delius user is unknown.   However
# this is only tolerated for a temporary period until the mapping is added, which is why this
# metric alert identifies the situation rather than an application or database error being
# used to block the action altogether.

. ~/.bash_profile

sqlplus -s / as sysdba <<EOSQL
SET ECHO OFF
SET FEEDBACK OFF
SET SERVEROUT ON
DECLARE
  v_count NUMBER;
BEGIN
  BEGIN
    -- Count number of entries in the R_SERVICE_USER table which do not have a USER_ mapping
    EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM delius_app_schema.r_service_user WHERE user_id IS NULL' INTO v_count;
  EXCEPTION
    WHEN OTHERS THEN
      -- Ignore table does not exist or database not open
      IF SQLCODE = -942 OR SQLCODE=-1219 THEN
        v_count := 0;
      ELSE
        RAISE;
      END IF;
  END;

  DBMS_OUTPUT.PUT_LINE(v_count);
END;
/
EXIT
EOSQL