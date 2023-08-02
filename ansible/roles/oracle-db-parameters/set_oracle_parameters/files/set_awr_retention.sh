#!/bin/bash

AWR_RETENTION_DAYS=$1

. ~/.bash_profile

sqlplus -s /  as sysdba <<EOF
SET LINES 1000
SET PAGES 0
SET FEEDBACK ON
SET HEADING OFF
WHENEVER SQLERROR EXIT FAILURE

DECLARE
   l_retention_minutes INTEGER;
BEGIN
   l_retention_minutes := ${AWR_RETENTION_DAYS} * 60 * 24;
   DBMS_WORKLOAD_REPOSITORY.modify_snapshot_settings (retention => l_retention_minutes);
END;
/

EXIT
EOF