#!/bin/bash

set -euo pipefail

# Install 19c Apex 
cd /u01/app/oracle/product/19c/db_1/apex

sqlplus -s / as sysdba <<EOSQL

WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE

DECLARE
	apex_tablespace_count INTEGER;
BEGIN
	SELECT COUNT(*)
		INTO apex_tablespace_count
		FROM dba_tablespaces
	 WHERE tablespace_name = 'APEX';

	IF apex_tablespace_count = 0 THEN
		EXECUTE IMMEDIATE 'create tablespace APEX datafile size 500M autoextend on next 100M';
	END IF;
END;
/

@apexins.sql APEX APEX TEMP /i/

SET SERVEROUTPUT ON
EXEC SYS.validate_apex;

EXIT

EOSQL
