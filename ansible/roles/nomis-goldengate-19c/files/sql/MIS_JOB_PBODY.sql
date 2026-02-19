CREATE OR REPLACE PACKAGE BODY MIS_JOB_PKG AS
/*
 *  NOMIS MIS Goldengate code.
 *  
 *  Description:  	This script creates procedures to support
 *                      Oracle Goldengate jobs for Prison-NOMIS release 1.0e.
 *  
 *  Version: 		1.0e
 *
 *  Author:		
 *
 *  Date:		
 * 
 *  Change History:	Version:  Date:	    Author:	Description:	
 *
 *			1.0e.59	  01/05/13  R. Taylor	Added purge_records procedure (defect 19143).
 */

  FUNCTION get_version RETURN varchar2 IS
  -- packaged function get_version
  -- will return a VARCHAR2 string containing a package version number
  BEGIN
    return g_version;
  END;


    PROCEDURE log_apply (
        p_tgt_owner 	IN     VARCHAR2
    ) IS
    -- packaged procedure log_apply records transaction watermark details
    -- for all apply processes associated with the target table owner

        v_plsql			    varchar2(2000); 
        v_apply_name_list 	mis_gen_pkg.apply_list;
        v_msg_number 		number;
        v_msg_date 	 		date;
        v_status 			varchar2(20) := '';
        v_apply_error 		number := 0;

    BEGIN
        -- get list of apply processes
        v_apply_name_list := mis_gen_pkg.get_apply_list(p_tgt_owner);

        -- define SCN select statement (low watermark, all transactions up to this are applied)
        v_plsql := 'select p.applied_message_number, p.APPLIED_MESSAGE_CREATE_TIME, ' ||
                        'a.status, a.error_number ' ||
                    'from dba_apply_progress p, dba_apply a ' ||
                    'where a.apply_name = :apply_name ' ||
                    'and p.apply_name = a.apply_name';

        -- stop all apply processes
        FOR i IN 1..v_apply_name_list.count
        LOOP
            -- get max applied SCN
            execute immediate v_plsql
            into v_msg_number, v_msg_date, v_status, v_apply_error
            using v_apply_name_list(i);
            -- log message
            mis_gen_pkg.log_strm_error (p_tgt_owner, 'log_apply', p_err_code => v_apply_error, p_text =>
                'Apply process ' || v_apply_name_list(i) || ' is ' || v_status || '. '||
                'Applied SCN is ' || v_msg_number || ' (message created '||
                to_char(v_msg_date,'DD-MON-YYYY HH24:MI:SS') || ').');
        END LOOP;

    EXCEPTION

        WHEN OTHERS THEN
            mis_gen_pkg.log_strm_error (p_tgt_owner, 'log_apply', p_err_code => SQLCODE, p_text => SQLERRM ||' Error line :' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            RAISE;

    END;

    PROCEDURE log_purge  
    IS
    -- packaged procedure log_purge
    -- will delete archived logs which are purgable according to the retention policy
    -- and have also been mined by the streams processes.
    
        l_base_dir      VARCHAR2(500);
        l_file          VARCHAR2(500);
        l_exists 		BOOLEAN;
        l_file_length 	NUMBER;
        l_blocksize 	NUMBER;
    BEGIN

        FOR c_logs IN
        (SELECT name
        FROM   dba_registered_archived_log 
        WHERE  purgeable = 'YES')
        LOOP
            l_base_dir := substr( c_logs.name, 1, 
                                instr(c_logs.name, '/', -1, 1) -1);
            l_file := substr( c_logs.name, instr(c_logs.name, '/', -1, 1) +1 );
            utl_file.fgetattr( g_mis_archived_dir, l_file, l_exists, l_file_length, l_blocksize );
            IF l_exists = TRUE THEN
                utl_file.fremove( g_mis_archived_dir, l_file );
            END IF;
        END LOOP;

    END log_purge;

    PROCEDURE create_log_purge_job 
    IS 
    -- based on mis_log_purge_job.sql
        -- v1.0e.3
    BEGIN
        begin
            -- drop the old streams job if it exists
            DBMS_SCHEDULER.DROP_JOB ('strmadmin.weekly_log_purge');
        exception 
        when others then 
            null;
        end;
        begin
            DBMS_SCHEDULER.DROP_JOB (mis_gen_pkg.g_mis_owner||'.weekly_log_purge');
        exception 
        when others then 
            null;
        end;
        dbms_scheduler.create_job(
            job_name => '"'||mis_gen_pkg.g_mis_owner||'"."WEEKLY_LOG_PURGE"',
            job_type => 'PLSQL_BLOCK',
            job_action => 'begin mis_job_pkg.log_purge(); end;',
            repeat_interval => 'FREQ=WEEKLY;BYDAY=WED;BYHOUR=22;BYMINUTE=30',
            start_date => systimestamp at time zone 'GB',
            job_class => 'DEFAULT_JOB_CLASS',
            comments => 'Ensure processed source redo logs are purged.',
            auto_drop => FALSE,
            enabled => TRUE);
    END create_log_purge_job;

    PROCEDURE create_audit_reference_job
    IS 
    -- audit_reference_job.sql
    -- v1.0e.6
    -- logs reference table apply progress and
    -- uses populate_offender_refs to write to AUDIT_OFFENDER_REFS
        v_RUN_HOURS_LIST varchar2(20) := '05,13,21';
    BEGIN
        begin
            dbms_scheduler.drop_job('AUDIT_REFERENCE');
        exception
        when others then null;
        end;
        --
        begin
        DBMS_SCHEDULER.CREATE_JOB (
            job_name => 'audit_reference',
            job_type => 'PLSQL_BLOCK',
            job_action => 
                'declare
                    v_plsql varchar2(200);
                begin
                    v_plsql := ''alter system flush shared_pool'';
                    execute immediate v_plsql;
                    MIS_JOB_PKG.log_apply('''||mis_gen_pkg.g_mis_owner||''');
                    AUDITDATA_JOB_PKG.populate_offender_refs;
                end;',
            start_date => systimestamp at time zone 'GB',
            repeat_interval => 'FREQ=DAILY;BYHOUR='||v_RUN_HOURS_LIST||';BYMINUTE=00;BYSECOND=00',
            enabled => TRUE,
            auto_drop => FALSE,
            comments => 'Job to ensure that audit references are refreshed at '||v_RUN_HOURS_LIST||' hours.');
        end;
        dbms_scheduler.run_job('audit_reference', FALSE);
    END create_audit_reference_job;



  PROCEDURE PRUNE_TABLE (
    p_staging_owner 	IN     varchar2,
    p_table      in varchar2,
    p_date_col   in varchar2,
    p_prune_date in date,
    p_key_col    in varchar2 default null,
    p_loop_size  in integer default 1000000
  ) IS
  -- local procedure prune_table
  -- will delete entries older than p_prune_date from p_table

  v_statement           varchar2(1000);
  v_min_key             integer := null;
  v_max_key             integer := null;
  v_lim_key             integer;
  v_message             varchar2(1000);

  pragma AUTONOMOUS_TRANSACTION;

  BEGIN

  IF p_key_col IS NOT NULL THEN

    -- Get the min and max key values prior to the prune date

    v_statement := 'select min(' || p_key_col || '), max(' || p_key_col || ')' ||
		        ' from ' || p_staging_owner  || '.' || p_table ||
                   ' where ' || p_date_col || ' < :prune_date';
    EXECUTE IMMEDIATE v_statement into v_min_key, v_max_key using p_prune_date;

    IF v_min_key IS NOT NULL THEN

      -- loop through key values in increments of p_loop_size
      LOOP
        v_lim_key := least(v_min_key+p_loop_size, v_max_key);

        -- delete rows from p_table by key value
        v_statement := 'delete from ' || p_staging_owner  || '.' || p_table ||
                       ' where ' || p_key_col || ' <= :key_value';
        EXECUTE IMMEDIATE v_statement using v_lim_key;

        v_message := SQL%ROWCOUNT || ' rows older than ' || to_char(p_prune_date,'DD-MON-YYYY') || ' deleted from ' || p_table || '.';

        COMMIT;

        --DBMS_OUTPUT.PUT_LINE(v_message);
        mis_gen_pkg.log_strm_error(p_staging_owner, 'prune_table', p_tgt_table=>p_table,
                       p_err_code=>0, p_text=>v_message);

        EXIT WHEN v_lim_key >= v_max_key;
        v_min_key := v_lim_key;
      END LOOP;

    END IF;

  ELSE
    -- delete rows from p_table by date
    v_statement := 'delete from ' || p_staging_owner  || '.' || p_table ||
                   ' where ' || p_date_col || ' < :prune_date';
    EXECUTE IMMEDIATE v_statement using p_prune_date;

    v_message := SQL%ROWCOUNT || ' rows older than ' || to_char(p_prune_date,'DD-MON-YYYY') || ' deleted from ' || p_table || '.';

    COMMIT;

    --DBMS_OUTPUT.PUT_LINE(v_message);
    mis_gen_pkg.log_strm_error(p_staging_owner, 'prune_table', p_tgt_table=>p_table,
                   p_err_code=>0, p_text=>v_message);
  END IF;

  COMMIT;

  EXCEPTION
    WHEN OTHERS THEN
        mis_gen_pkg.log_strm_error (p_staging_owner, 'prune_table', p_tgt_table=>p_table,
                        p_err_code => SQLCODE, p_text => SQLERRM ||' Error line :' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;
  END PRUNE_TABLE ;


  PROCEDURE PURGE_RECORDS (
    p_staging_owner 	IN     varchar2,
    p_months     in integer default 26
  ) IS
  -- packaged procedure purge_records
  -- will delete rows older than p_months months from historical tables

  v_prune_date          date := add_months(trunc(sysdate),-p_months);

  BEGIN

  -- Remove table entries prior to the prune date

  prune_table(p_staging_owner, 'strm_error_log', 'error_datetime', v_prune_date);

  EXCEPTION
    WHEN OTHERS THEN
        mis_gen_pkg.log_strm_error (p_staging_owner, 'purge_records',
                        p_err_code => SQLCODE, p_text => SQLERRM ||' Error line :' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;
  END PURGE_RECORDS ;


END MIS_JOB_PKG;
/

show errors
