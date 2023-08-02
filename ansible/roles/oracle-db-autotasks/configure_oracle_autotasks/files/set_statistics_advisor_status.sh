#!/bin/bash

# As of Oracle 19.9 the AUTO_STATS_ADVISOR_TASK can only be managed once a patch has been applied.
# See MOS Note: Optimizer Statistics Advisor Task Consumes Excessive PGA Memory and ORA-4036 Occurs. (Doc ID 2727813.1) 
#
# We return "UNKNOWN" if the query fails due to the absense of the patch.
# (Do not check for presence of patch directly, since patch number may differ or functionality may be native in later releases).
#

AUTO_STATS_ADVISOR_TASK_ENABLED=$1

. ~/.bash_profile

sqlplus -s /  as sysdba <<EOF
SET ECHO ON
SET FEEDBACK ON

BEGIN
   dbms_stats.set_global_prefs('AUTO_STATS_ADVISOR_TASK','${AUTO_STATS_ADVISOR_TASK_ENABLED}');
END;
/
EOF