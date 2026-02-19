spool auditdata_setup.log

DEFINE GGUSER = ggint

-- connect / as sysdba

-- for apply dml handler processing:
grant select on DBA_APPLY_DML_HANDLERS to auditdata;
grant select on DBA_REGISTERED_ARCHIVED_LOG to auditdata;
grant select on dba_capture to auditdata;

-- do we need public synonyms? created for auditdata job but maybe don't need public synonyms for the package to compile?
DECLARE
	l_grant varchar2(1000);
BEGIN
	FOR i IN (SELECT tgt_table FROM AUDITREF.STRM_TAB_CONTROL ORDER BY 1) LOOP
		l_grant := 'grant select on AUDITREF.'||i.tgt_table||' to &GGUSER';
		l_grant := 'create or replace public synonym '||i.tgt_table||' for AUDITREF.'||i.tgt_table;
		EXECUTE IMMEDIATE l_grant;
	END LOOP;
END;
/

execute DBMS_STREAMS_AUTH.GRANT_ADMIN_PRIVILEGE('GGINT');
grant execute on sys.dbms_lob to "GGINT";
grant execute on sys.dbms_reputil2 to "GGINT";


grant dba to &GGUSER;

grant select any table to &GGUSER;

grant insert any table to &GGUSER;

grant update any table to &GGUSER;

grant delete any table to &GGUSER;

grant write on directory AUD_ARCHIVELOG_DIR to &GGUSER;

grant read on directory AUD_ARCHIVELOG_DIR to &GGUSER;

grant execute on sys.dbms_lock to &GGUSER;

grant create any procedure to &GGUSER;

grant alter any procedure to &GGUSER;

grant drop any procedure to &GGUSER;

grant select any sequence to &GGUSER;

--grant select on sys.gv_$streams_apply_server to &GGUSER;

grant analyze any to &GGUSER;

connect auditdata/Xsw2#edc

@AUDITDATA_GEN_PKG.sql
@AUDITDATA_CONV_PKG.sql
@AUDITDATA_DML_PKG.sql
@AUDITDATA_JOB_PKG.sql

@AUDITDATA_GEN_PBODY.sql
@AUDITDATA_CONV_PBODY.sql
@AUDITDATA_DML_PBODY.sql
@AUDITDATA_JOB_PBODY.sql

create or replace public synonym AUDITDATA_GEN_PKG for AUDITDATA_GEN_PKG;
create or replace public synonym AUDITDATA_CONV_PKG for AUDITDATA_CONV_PKG;
create or replace public synonym AUDITDATA_DML_PKG for AUDITDATA_DML_PKG;
create or replace public synonym AUDITDATA_JOB_PKG for AUDITDATA_JOB_PKG;
grant execute on AUDITDATA_GEN_PKG to &GGUSER;
grant execute on AUDITDATA_CONV_PKG to &GGUSER;
grant execute on AUDITDATA_DML_PKG to &GGUSER;
grant execute on AUDITDATA_JOB_PKG to &GGUSER;

EXECUTE auditdata_dml_pkg.apply_DML_CONF;

EXECUTE auditdata_dml_pkg.apply_DML_deCONF;

begin 
    DBMS_CAPTURE_ADM.INCLUDE_EXTRA_ATTRIBUTE(capture_name => 'OGG$CAP_AUDDTCAP', attribute_name => 'USERNAME', include => true);
    DBMS_CAPTURE_ADM.INCLUDE_EXTRA_ATTRIBUTE(capture_name => 'OGG$CAP_AUDDTCAP', attribute_name => 'SESSION#', include => true);
end;
/





DEFINE SOURCE_DATABASE = T1CNOM.REGRESS.RDBMS.DEV.US.ORACLE.COM
--DEFINE SOURCE_SERVICE = cnomis
DEFINE SOURCE_SERVICE = T1CNOM

create database link &SOURCE_DATABASE
connect to ggint identified by g0ldeng1te using '&SOURCE_SERVICE'
/



CREATE OR REPLACE PROCEDURE auditdata.maintain_module_config (
    p_mod_name in varchar2,
    p_exclude  in char) IS
BEGIN
    AUDITDATA_DML_PKG.maintain_module_config(p_mod_name, p_exclude);
END;
/

alter trigger auditdata.module_capture_config_t1 compile;

CREATE INDEX auditdata.audit_error_datetime_indx ON auditdata.audit_error(error_datetime);

spool off 


in T1CNOM:
- builds data dictionary in the Logs (need to create a day job to run this):
    execute DBMS_LOGMNR_D.BUILD(options => DBMS_LOGMNR_D.STORE_IN_REDO_LOGS);

    sqlplus '/as sysdba'
SQL>BEGIN
  DBMS_SCHEDULER.CREATE_JOB (
    job_name         => 'BUILD_LOGMINER_DICT_HOURLY',
    job_type         => 'PLSQL_BLOCK',
    job_action       => '
      BEGIN 
        DBMS_LOGMNR_D.BUILD(
          options => DBMS_LOGMNR_D.STORE_IN_REDO_LOGS
        ); 
      END;',
    start_date       => SYSTIMESTAMP,
    repeat_interval  => 'FREQ=DAILY; INTERVAL=1',
    enabled          => TRUE,
    comments         => 'Build LogMiner dictionary every hour for Integrated Extract');
END;
/

see for more details as to why: https://alexlima.com/2025/05/30/why-you-should-rebuild-the-logminer-dictionary-periodically-for-oracle-goldengate/

- find scn of redo log with the data dict in it:
SELECT 
  sequence#,
  first_change#,
  TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS') AS completion_time,
  dictionary_begin,
  dictionary_end
   FROM v$archived_log 
   WHERE (dictionary_begin = 'YES' OR dictionary_end = 'YES') AND 
      STANDBY_DEST = 'NO' AND
      NAME IS NOT NULL AND 
      STATUS = 'A' ORDER BY 
  sequence# DESC;

-- generate ddl for all OMS_OWNER tables
set serveroutput on
declare
  metadata_handle number;
  transform_handle number;
  ddl_handle number;
  result_array sys.ku$_ddls;
begin
  metadata_handle := dbms_metadata.open('TABLE');
  transform_handle := dbms_metadata.add_transform(metadata_handle, 'MODIFY');
  dbms_metadata.set_remap_param(transform_handle, 'REMAP_SCHEMA', 'OMS_OWNER', 'GG_OMS_OWNER');
  ddl_handle := dbms_metadata.add_transform(metadata_handle, 'DDL');

  dbms_metadata.set_filter(metadata_handle, 'SCHEMA', 'OMS_OWNER');
  dbms_metadata.set_filter(metadata_handle, 'NAME', 'OFFENDERS');
  dbms_metadata.set_transform_param(transform_handle, 'SEGMENT_ATTRIBUTES', false);
  
  loop
    result_array := dbms_metadata.fetch_ddl(metadata_handle);
    exit when result_array is null;
      for i in result_array.first..result_array.last loop
      dbms_output.put_line(result_array(i).ddltext);
    end loop;
  end loop; 
  dbms_metadata.close(metadata_handle);
end;
/

SET LONG 2000000
SET PAGESIZE 0
BEGIN
   DBMS_METADATA.set_transform_param(DBMS_METADATA.session_transform, 'SQLTERMINATOR', true);
   DBMS_METADATA.set_transform_param(DBMS_METADATA.session_transform, 'PRETTY', true);
   DBMS_METADATA.set_transform_param(DBMS_METADATA.session_transform, 'SIZE_BYTE_KEYWORD', false);
   DBMS_METADATA.set_transform_param(DBMS_METADATA.session_transform, 'SEGMENT_ATTRIBUTES', false);
   DBMS_METADATA.set_transform_param(DBMS_METADATA.session_transform, 'STORAGE', false);
--   DBMS_METADATA.set_transform_param(DBMS_METADATA.session_transform, 'CONSTRAINTS', false);
   DBMS_METADATA.set_transform_param(DBMS_METADATA.session_transform, 'REF_CONSTRAINTS', false);
   DBMS_METADATA.set_transform_param(DBMS_METADATA.session_transform, 'TABLESPACE', false);
   DBMS_METADATA.set_transform_param(DBMS_METADATA.session_transform, 'PARTITIONING', false);
END;
/

SELECT replace(DBMS_METADATA.get_ddl ('TABLE', table_name, owner),'OMS_OWNER','GG_OMS_OWNER')
FROM   all_tables
WHERE  owner      = 'OMS_OWNER'
and table_name = 'OFFENDERS'
order by table_name

spool table_ddl.sql
/

spool off
