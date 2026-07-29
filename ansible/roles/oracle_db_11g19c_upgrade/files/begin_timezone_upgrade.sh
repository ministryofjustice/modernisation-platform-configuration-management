#!/bin/bash

sqlplus -s / as sysdba <<EOSQL
WHENEVER SQLERROR EXIT FAILURE
SET SERVEROUTPUT ON
DECLARE
  l_tz_version PLS_INTEGER;
BEGIN
  SELECT DBMS_DST.get_latest_timezone_version
  INTO   l_tz_version
  FROM   dual;

  DBMS_OUTPUT.put_line('l_tz_version=' || l_tz_version);
  DBMS_DST.begin_upgrade(l_tz_version);
END;
/
EXIT
EOSQL
