#!/bin/bash

. ~/.bash_profile

sqlplus -s /  as sysdba <<EOF
WHENEVER SQLERROR EXIT FAILURE
SET FEEDBACK OFF
SET SERVEROUT ON
BEGIN
   DBMS_SCHEDULER.set_scheduler_attribute (
         attribute => 'default_timezone',
         value     => 'Europe/London'
   );
END;
/
EOF