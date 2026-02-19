spool auditref_setup.log

DEFINE GGUSER = ggint

-- connect / as sysdba

-- for apply dml handler processing:
grant select on DBA_APPLY_DML_HANDLERS to auditref;
grant select on DBA_REGISTERED_ARCHIVED_LOG to auditref;
grant select on dba_capture to auditref;
grant execute on DBMS_APPLY_ADM to auditref;
grant execute on DBMS_LOCK to auditref;
grant execute on DBMS_CAPTURE_ADM to auditref;
grant execute on DBMS_APPLY_ADM to auditref;
GRANT SELECT ON V$STREAMS_APPLY_SERVER TO auditref;
grant select on dba_registered_archived_log to auditref;
grant execute on DBMS_UTILITY to auditref;

-- couldn't create packages in auditref so had to run this:
grant connect, resource to auditref;

-- couldn't create the dml handler procs without this
grant create procedure to auditref;

connect auditref/Xsw2#edc

@MIS_BATCH_PKG.sql
@MIS_DML_PKG.sql
@MIS_GEN_PKG.sql
@MIS_GG_CTRL_PKG.sql
@MIS_JOB_PKG.sql
@MIS_TAB_CTRL_PKG.sql

@MIS_GEN_PBODY.sql
@MIS_DML_PBODY.sql
@MIS_BATCH_PBODY.sql
@MIS_GG_CTRL_PBODY.sql
@MIS_JOB_PBODY.sql
@MIS_TAB_CTRL_PBODY.sql


grant execute on MIS_BATCH_PKG to &GGUSER;
grant execute on MIS_DML_PKG to &GGUSER;
grant execute on MIS_GG_CTRL_PKG to &GGUSER;
grant execute on MIS_JOB_PKG to &GGUSER;
grant execute on MIS_TAB_CTRL_PKG to &GGUSER;

connect / as sysdba

-- mis versions of dml handler conf procedures
EXECUTE mis_dml_pkg.set_apply_handlers('AUDITREF');

--EXECUTE mis_dml_pkg.clear_apply_handlers;


-- have to create as sys as auditref has insuffient privs
create or replace public synonym MIS_BATCH_PKG for auditref.MIS_BATCH_PKG;
create or replace public synonym MIS_DML_PKG for auditref.MIS_DML_PKG;
create or replace public synonym MIS_GG_CTRL_PKG for auditref.MIS_GG_CTRL_PKG;
create or replace public synonym MIS_JOB_PKG for auditref.MIS_JOB_PKG;
create or replace public synonym MIS_TAB_CTRL_PKG for auditref.MIS_TAB_CTRL_PKG;

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

