#!/bin/bash

# As of Oracle 19.9 the AUTO_STATS_ADVISOR_TASK can only be managed once a patch has been applied.
# See MOS Note: Optimizer Statistics Advisor Task Consumes Excessive PGA Memory and ORA-4036 Occurs. (Doc ID 2727813.1) 
#
# We return "UNKNOWN" if the query fails due to the absense of the patch.
# (Do not check for presence of patch directly, since patch number may differ or functionality may be native in later releases).
#

. ~/.bash_profile

sqlplus -s /  as sysdba <<EOF
SET LINES 1000
SET PAGES 0
SET FEEDBACK OFF
SET HEADING OFF
SET SERVEROUT ON
DECLARE 
   l_auto_stats_advisor_task VARCHAR2(10);
   e_user_defined_exception  EXCEPTION;
   PRAGMA EXCEPTION_INIT( e_user_defined_exception, -20001 );
BEGIN
   l_auto_stats_advisor_task := dbms_stats.get_prefs('AUTO_STATS_ADVISOR_TASK');
   DBMS_OUTPUT.put_line(l_auto_stats_advisor_task);
   exception
      when e_user_defined_exception
      then
         if SQLERRM='ORA-20001: Invalid input values for pname'
         then
            DBMS_OUTPUT.put_line('UNKNOWN');
         else
            raise;
         end if;
END;
/
EXIT
EOF