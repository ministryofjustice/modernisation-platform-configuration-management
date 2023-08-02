#!/bin/bash

. ~/.bash_profile

sqlplus -s /  as sysdba <<EOF
WHENEVER SQLERROR EXIT FAILURE
SET FEEDBACK OFF
SET SERVEROUT ON
DECLARE
    v_value VARCHAR2(400);
BEGIN
    DBMS_SCHEDULER.get_scheduler_attribute (
        attribute => 'default_timezone',
        value     => v_value);
    DBMS_OUTPUT.PUT_LINE(v_value);
END;
/
EOF