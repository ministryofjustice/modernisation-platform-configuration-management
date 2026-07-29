#!/bin/bash

. ~/.bash_profile

sqlplus -s / as sysdba <<EOSQL
SET HEADING OFF
/*
 *  This script can be run against all upgraded primary databases.
 *  ALS-2047 and ALS-2050 will perform no actions on non-Delius databases.
 *
 */


SET SERVEROUT ON

-- *******************************************
-- ALS-2047 Remove Invalid DELIUS_CFO Synonyms
-- *******************************************
BEGIN
FOR x IN (SELECT synonym_name
          FROM   dba_synonyms
          WHERE  owner = 'DELIUS_CFO'
          AND    synonym_name IN ('JSON','JSON_AC','JSON_EXT','JSON_LIST','JSON_PARSER',
                                  'JSON_PRINTER','JSON_VALUE','JSON_VALUE_ARRAY','SB_XML'))
LOOP
    EXECUTE IMMEDIATE 'DROP SYNONYM delius_cfo.'||x.synonym_name;
    DBMS_OUTPUT.put_line('Dropped synonym DELIUS_CFO.'||x.synonym_name||'.');
END LOOP;
END;
/

-- *******************************************
-- ALS-2050 Add New Columns to Audit History
-- *******************************************
DECLARE
   l_table_exists       INTEGER;
   l_new_columns_exist  INTEGER;
BEGIN
   SELECT COUNT(*)
   INTO   l_table_exists
   FROM   user_tables
   WHERE  table_name = 'HIST_AUD\$';

   SELECT COUNT(*) 
   INTO   l_new_columns_exist
   FROM   user_tab_columns
   WHERE  table_name = 'HIST_AUD\$'
   AND    column_name IN ('RLS\$INFO','CURRENT_USER');
   
   IF l_table_exists = 1 AND l_new_columns_exist != 2
   THEN
      EXECUTE IMMEDIATE 'ALTER TABLE hist_aud\$ ADD (rls\$info CLOB, current_user VARCHAR2(128))';
      DBMS_OUTPUT.put_line('Added new columns to HIST_AUD\$.');
   END IF;
END;
/

-- *******************************************
-- ALS-2052 Remove XQuery Java Classes
-- (See MOS Note 2647021.1)
-- *******************************************

BEGIN

DELETE FROM obj\$
WHERE       type#=10
AND         name LIKE '%/xquery/%';
IF SQL%ROWCOUNT > 0 THEN
   DBMS_OUTPUT.put_line('Dropped '||SQL%ROWCOUNT||' local non-existent objects.');
END IF;

FOR x IN (SELECT name
          FROM   obj\$
          WHERE  owner#=0
          AND    type#=29
          AND    name LIKE '%/xquery/%'
          AND    status=5) LOOP
   EXECUTE IMMEDIATE 'DROP PUBLIC SYNONYM "'||x.name||'"';
   EXECUTE IMMEDIATE 'DROP JAVA CLASS "'||x.name||'"';
   DBMS_OUTPUT.put_line('Dropped synonym and Java Class '||x.name||'.');
END LOOP;

END;
/


-- *******************************************
-- ALS-2086 Statspack Upgrade Fix
-- (See MOS Note 2447241.1)
-- *******************************************

DECLARE
   l_statspack_installed          INTEGER;
   l_remaster_type_added          INTEGER;
   l_iostat_function_detail_added INTEGER;
BEGIN

   -- Check if PERFSTAT schema exists (Will not be in use on some databases which use Diagnostics and Tuning)
   SELECT COUNT(*)
   INTO   l_statspack_installed
   FROM   dba_tables
   WHERE  owner = 'PERFSTAT';
   
   -- Only perform actions if the PERFSTAT schema exists and is populated
   IF l_statspack_installed > 0
   THEN
   
     SELECT COUNT(*)
     INTO   l_remaster_type_added
     FROM   dba_tab_columns
     WHERE  owner = 'PERFSTAT'
     AND    table_name = 'STATS\$DYNAMIC_REMASTER_STATS'
     AND    column_name = 'REMASTER_TYPE';
     
     -- Add new column to stats$dynamic_remaster_stats if it does not already exist
     IF l_remaster_type_added=0 THEN 
     
        EXECUTE IMMEDIATE q'[ALTER TABLE perfstat.stats\$dynamic_remaster_stats 
                             ADD (remaster_type VARCHAR2(11) DEFAULT 'AFFINITY' NOT NULL)]';
     END IF;
     
     -- Replace existing constraint (may be re-run)
     EXECUTE IMMEDIATE q'[ALTER TABLE perfstat.stats\$dynamic_remaster_stats 
                          DROP CONSTRAINT stats\$dynamic_rem_stats_pk]';                         
     EXECUTE IMMEDIATE q'[ALTER TABLE perfstat.stats\$dynamic_remaster_stats 
                          ADD  CONSTRAINT stats\$dynamic_rem_stats_pk PRIMARY KEY (snap_id, dbid, instance_number,remaster_type)]';
                          
     -- Grant privileges required on data dictionary (may be re-run)
     EXECUTE IMMEDIATE q'[GRANT SELECT ON v_\$iostat_function_detail TO perfstat]';
     
     SELECT COUNT(*)
     INTO   l_iostat_function_detail_added
     FROM   dba_tables
     WHERE  owner = 'PERFSTAT'
     AND    table_name = 'STATS\$IOSTAT_FUNCTION_DETAIL';
     
     -- Add new PERFSTAT table if only if it does not already exist
     IF l_iostat_function_detail_added=0 THEN
     
        EXECUTE IMMEDIATE q'[CREATE TABLE perfstat.stats\$iostat_function_detail
                             (snap_id         NUMBER NOT NULL
                             ,dbid            NUMBER NOT NULL
                             ,instance_number NUMBER NOT NULL
                             ,func_id         NUMBER
                             ,func_name       VARCHAR2(20)
                             ,filetyp_id      NUMBER
                             ,filetyp_name    VARCHAR2(30)
                             ,smallrd_mb      NUMBER
                             ,smallwt_mb      NUMBER
                             ,largerd_mb      NUMBER
                             ,largewt_mb      NUMBER
                             ,num_waits       NUMBER
                             ,wait_time       NUMBER
                             ,CONSTRAINT stats\$iostat_func_pk 
                              PRIMARY KEY (snap_id, dbid, instance_number, func_id, filetyp_id)
                              USING INDEX TABLESPACE statspack_data
                              STORAGE (INITIAL 1m NEXT 1m PCTINCREASE 0)
                             ,CONSTRAINT stats\$iostat_func_fk 
                              FOREIGN KEY (snap_id, dbid, instance_number)
                              REFERENCES stats\$snapshot ON DELETE CASCADE
                             ) TABLESPACE statspack_data
                             STORAGE (INITIAL 1m NEXT 1m PCTINCREASE 0)
                             PCTFREE 5 PCTUSED 40]';
     END IF;

     -- Replace public synonym for the new table
     EXECUTE IMMEDIATE q'[CREATE OR REPLACE PUBLIC SYNONYM stats\$iostat_function_detail 
                          FOR perfstat.stats\$iostat_function_detail]';

     DBMS_OUTPUT.put_line('Statspack fix applied.');
  ELSE
     DBMS_OUTPUT.put_line('Statspack not in use.');
  END IF;
  
END;
/



-- ********************************************
-- No Invalid Objects Should Remain
-- ********************************************

-- Recompile any stray objects
@?/rdbms/admin/utlrp

-- Report any remaining invalid objects
COLUMN owner       FORMAT a30
COLUMN object_type FORMAT a30
COLUMN object_name FORMAT a30
SET LINES 120

PROMPT Invalid Objects Report
PROMPT ======================

SELECT owner,object_type,object_name
FROM   dba_objects
WHERE  status != 'VALID';

EOSQL