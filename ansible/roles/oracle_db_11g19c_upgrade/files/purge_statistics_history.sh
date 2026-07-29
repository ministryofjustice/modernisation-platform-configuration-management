#!/bin/bash
#
#   Bug 19855835 results in slowness upgrading from 11g to 18c when trying to create indexes on the
#   statistics history tables.   This should not be a huge problem on Delius where these tables
#   are small but they are huge in MIS.
#
#   Unfortunately this patch is incompatible with the PSU currently used in production and no merge
#   patch is available as we are now in extended support.
#
#   Upgrading to a new PSU before upgrading to 18c would be add extra disruption, so instead we
#   will simply purge these tables to avoid the slowness.   Since we have upgraded the database
#   old statistics will be of limited value anyway.     
#
#   However, we will export the data first just in case we do ever need it.
#

sqlplus -s / as sysdba <<EOSQL
COLUMN instance_name NEW_VALUE ORACLE_SID
SELECT instance_name
  FROM v\$instance;
CREATE OR REPLACE DIRECTORY preupgrade_stats_history_dir AS '/u01/app/oracle/admin/&&ORACLE_SID/dpdump';
-- Data Pump will not allow us to export data directly from SYS so we need to temporarily relocate it
CREATE USER preupgrade_stats_history_user IDENTIFIED BY keepthislocked DEFAULT TABLESPACE users ACCOUNT LOCK QUOTA UNLIMITED ON users;
BEGIN
FOR stat_tables IN (SELECT table_name
                    FROM   dba_tables
                    WHERE  owner = 'SYS'
                    AND    table_name LIKE 'WRI%OPTSTAT%')
LOOP
   EXECUTE IMMEDIATE 'CREATE TABLE preupgrade_stats_history_user.'||stat_tables.table_name||
                     ' AS SELECT * FROM sys.'||stat_tables.table_name;
END LOOP;
END;
/
EXIT
EOSQL

expdp userid=\'/ as sysdba\' directory=preupgrade_stats_history_dir logfile=stats_history.log dumpfile=stats_history.dmp schemas=PREUPGRADE_STATS_HISTORY_USER reuse_dumpfiles=Y

# Now remove the export schema and purge the statistics
sqlplus -s / as sysdba <<EOSQL
DROP DIRECTORY preupgrade_stats_history_dir;
DROP USER preupgrade_stats_history_user CASCADE;
EXEC DBMS_STATS.purge_stats(before_timestamp=>SYSTIMESTAMP);
EXIT
EOSQL
