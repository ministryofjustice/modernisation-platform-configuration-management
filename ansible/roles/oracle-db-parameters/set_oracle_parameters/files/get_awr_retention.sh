#!/bin/bash

. ~/.bash_profile

sqlplus -s /  as sysdba <<EOF
SET LINES 1000
SET PAGES 0
SET FEEDBACK OFF
SET HEADING OFF
WHENEVER SQLERROR EXIT FAILURE
SELECT EXTRACT(DAY FROM retention) days_of_retention
FROM   dba_hist_wr_control
WHERE  dbid = (SELECT dbid
               FROM   v\$database);
EXIT
EOF