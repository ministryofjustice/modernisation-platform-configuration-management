CREATE OR REPLACE PACKAGE BODY MIS_GG_CTRL_PKG AS
/*
 *  NOMIS MIS Goldengate code.
 *  
 *  Description:  	This script creates procedures to support
 *                      Oracle Goldengate control processes for Prison-NOMIS release 1.0e.
 *                  Based on MIS_STRM_PKG1
 *  
 *  Version: 		1.0e
 *
 *  Author:		R. Taylor - EDS UK Ltd.
 *
 *  Date:		Monday, 21 May 2007.
 * 
 *  Change History:	Version:  Date:	    Author:	Description:	
 *
 *			1.1.0	  21/05/07  R. Taylor	Initial version for 1.1
 */

    -- Packaged function apply_process_error_count returns the number of apply processes
    -- for a particular staging table owner (if supplied) that have error status
    FUNCTION apply_process_error_count(
        p_staging_owner 	IN     varchar2 DEFAULT NULL,
        p_ignore_inactive 	IN     boolean DEFAULT TRUE
    ) RETURN number
    IS

        v_plsql			varchar2(2000); 
        v_apply_name_list mis_gen_pkg.apply_list;
        v_status 			varchar2(20);
        v_err_number 		number;
        v_err_total 		number := 0;

    BEGIN

        -- get list of apply processes
        v_apply_name_list := mis_gen_pkg.get_apply_list(p_staging_owner);

        v_plsql := 'select status, nvl(error_number,0) ' ||
                    'from dba_apply ' ||
                    'where apply_name = :apply_name';

        -- count apply process errors
        FOR i IN 1..v_apply_name_list.count
        LOOP
            execute immediate v_plsql
            into v_status, v_err_number
            using v_apply_name_list(i);
            IF v_status = 'ENABLED' THEN
                null;
            ELSIF v_err_number IN (0, mis_gen_pkg.g_scn_limit_reached) THEN
                IF p_ignore_inactive != TRUE THEN
                    v_err_total := v_err_total + 1;
                END IF;
            ELSE
                v_err_total := v_err_total + 1;
                mis_gen_pkg.log_strm_message (p_staging_owner, 'apply_process_error_count',
                                'Apply process ' || v_apply_name_list(i) || ' has error (' || v_err_number || ').');
            END IF;
        END LOOP;

        return v_err_total;

    EXCEPTION
        WHEN OTHERS THEN
            mis_gen_pkg.log_strm_error (p_staging_owner, 'apply_process_error_count',
                            p_err_code => SQLCODE, p_text => SQLERRM ||' Error line :' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
            RAISE;
    END;


  PROCEDURE set_stop_points (
      p_staging_owner 	IN     varchar2,
      p_points_set 	OUT    boolean
  ) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  -- packaged procedure set_stop_points
  -- sets or clears stop points for all capture and apply processes
  -- associated with a particular staging table owner
  
    l_plsql			varchar2(2000); 
    l_capture_scn 		number := 0;
    l_stop_scn 			number := null;
    l_after_scn 		number := null;
    l_stop_date 		date := null;
    l_staged_date 		date := null;
    l_points_set 		boolean := TRUE;
    l_old_batch_number		NUMBER(38,0) := -1;
    l_apply_scn 		number;

    PROCEDURE set_apply_stop (
        p_staging_owner IN     varchar2,
        p_queue_name 	IN     varchar2,
        p_stop_scn 	IN     number
    ) IS
    BEGIN
        -- process apply processes for queue
        FOR c_apply IN
           (select aa.apply_name, aa.status, aa.error_number, aa.max_applied_message_number,
                   aap.value maximum_scn
            from   all_apply_parameters aap, all_apply aa
            where  aa.queue_owner = mis_gen_pkg.g_queue_owner
            and    aa.queue_name = mis_gen_pkg.g_apply_queue_name
            and    aap.apply_name = aa.apply_name
            and    aap.parameter = 'MAXIMUM_SCN')
        LOOP
            IF p_stop_scn IS NULL THEN
                DBMS_APPLY_ADM.SET_PARAMETER(c_apply.apply_name, 'MAXIMUM_SCN', 'INFINITE');
            ELSIF c_apply.maximum_scn = 'INFINITE' THEN
                DBMS_APPLY_ADM.SET_PARAMETER(c_apply.apply_name, 'MAXIMUM_SCN', to_char(p_stop_scn));
            ELSIF to_number(c_apply.maximum_scn) < p_stop_scn THEN
                DBMS_APPLY_ADM.SET_PARAMETER(c_apply.apply_name, 'MAXIMUM_SCN', to_char(p_stop_scn));
            ELSE -- do not decrease a maximum already set
                null; 
            END IF;
        END LOOP;
    END;

  BEGIN
  
    -- determine number of latest batch for source
    l_old_batch_number := MIS_BATCH_PKG.get_batch_number(p_staging_owner, TRUE);
  
    IF l_old_batch_number > 1 THEN
        -- get details of existing active batch
        l_plsql := 'select nvl(staged_end_datetime, staged_start_datetime) ' ||
                     'from ' || mis_gen_pkg.g_mis_owner || '.ETL_LOAD_LOG ' ||
                    'where load_id = :load_id';  
        execute immediate l_plsql into l_staged_date using l_old_batch_number;
    END IF;

    -- process list of capture processes
    FOR c_capture IN
       (select ac.capture_name, ac.source_database, ac.status, ac.error_number,
               ac.captured_scn, ac.last_enqueued_scn, ac.applied_scn,
               ac.start_scn, ac.first_scn, acp.value maximum_scn
        from   all_capture_parameters acp, all_capture ac
        where  ac.queue_owner = mis_gen_pkg.g_queue_owner
        and    ac.queue_name = mis_gen_pkg.g_capture_queue_name
        and    acp.capture_name = ac.capture_name
        and    acp.parameter = 'MAXIMUM_SCN')
    LOOP
 
        -- get date for capture SCN value
        l_capture_scn := greatest(nvl(c_capture.captured_scn,0),
                                  nvl(c_capture.applied_scn,0),
                                  nvl(c_capture.start_scn,0),
                                  nvl(c_capture.first_scn,0));
        l_staged_date := nvl(l_staged_date,trunc(sysdate));
        
        -- determine potential stop point
        l_plsql := 'select min(stop_scn) from MIS_STOP_POINT@' || c_capture.source_database ||
                   ' where stop_point_date > :staged_date' ||
                     ' and stop_scn > :capture_scn';
        execute immediate l_plsql
        into  l_stop_scn
        using l_staged_date, l_capture_scn;

        IF l_stop_scn IS NULL THEN
            -- clear stop point
            set_apply_stop(p_staging_owner, mis_gen_pkg.g_capture_queue_name, l_stop_scn);
        
            DBMS_CAPTURE_ADM.SET_PARAMETER(c_capture.capture_name, 'MAXIMUM_SCN', 'INFINITE');
            DBMS_CAPTURE_ADM.SET_PARAMETER(c_capture.capture_name, '_CHECKPOINT_FORCE', 'Y');

            mis_gen_pkg.log_strm_error (p_staging_owner, 'set_stop_points',
                            p_err_code => 0, p_batch_id => l_old_batch_number,
                            p_text => 'Stop point cleared for ' || c_capture.capture_name || 
                                      ' (captured_scn=' || c_capture.captured_scn || ').');

            l_points_set := FALSE;
        ELSE
            -- set stop point
            l_plsql := 'select after_scn, stop_point_date from MIS_STOP_POINT@' ||
                       c_capture.source_database ||' where stop_scn = :scn';
            execute immediate l_plsql
            into  l_after_scn, l_stop_date
            using l_stop_scn;
        
            set_apply_stop(p_staging_owner, mis_gen_pkg.g_capture_queue_name, l_stop_scn);
         
            DBMS_CAPTURE_ADM.SET_PARAMETER(c_capture.capture_name, 'MAXIMUM_SCN', to_char(l_after_scn));

            mis_gen_pkg.log_strm_error (p_staging_owner, 'set_stop_points',
                            p_err_code => 0, p_batch_id => l_old_batch_number,
                            p_text => 'Stop point set for ' ||
                                c_capture.capture_name || ' (stop_date=' ||
                                to_char(l_stop_date,'DD-MON-YYYY HH24:MI:SS') || ' stop_scn=' ||
                                l_stop_scn || ' captured_scn=' || c_capture.captured_scn || ').');
        END IF;

    END LOOP;

    IF l_stop_date IS NULL THEN
        p_points_set := FALSE;
    ELSE
        p_points_set := l_points_set;
    END IF;

    COMMIT;

  EXCEPTION
  
    WHEN OTHERS THEN
        mis_gen_pkg.log_strm_error (p_staging_owner, 'set_stop_points', p_err_code => SQLCODE,
                        p_batch_id => l_old_batch_number, p_text => SQLERRM);
        ROLLBACK;
        RAISE;

  END;


  PROCEDURE wait_stop_points (
      p_staging_owner 	IN     varchar2,
      p_continue 	OUT    boolean
  ) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  -- packaged procedure wait_stop_points
  -- waits for all capture processes
  -- associated with a particular staging table owner to stop
  
    l_plsql			varchar2(2000); 
    l_stop_scn 			number := null;
    l_after_scn 		number := null;
    l_stop_date 		date := null;
    l_retry_limit 		number := mis_gen_pkg.g_retry_limit;
    l_stopped_count 	number;
    l_error_count 		number;
    l_active_count 		number;

    l_capture_name_list mis_gen_pkg.capture_list;
    l_continue 			boolean := FALSE;

    FUNCTION capture_stop_count (
      p_queue_name 	IN     varchar2
    ) RETURN NUMBER IS
    -- local function capture_stop_count returns the number of capture processes
    -- for a particular queue that have stopped due to SCN limit
          l_stopped_count number := 0;
    BEGIN
          select count(1) into l_stopped_count
          from   all_capture ac
          where  ac.queue_owner = mis_gen_pkg.g_queue_owner
          and    ac.queue_name = p_queue_name
          and    ac.status = 'DISABLED'
          and    ac.error_number = mis_gen_pkg.g_scn_limit_reached;
          return l_stopped_count;
    END;

    FUNCTION capture_error_count (
        p_queue_name 	IN     varchar2
    ) RETURN NUMBER IS
        l_error_count 	number := 0;
    BEGIN
        select count(1) into l_error_count
        from   all_capture ac
        where  ac.queue_owner = mis_gen_pkg.g_queue_owner
        and    ac.queue_name = p_queue_name
        and    ac.status != 'ENABLED'
        and    ac.error_number != mis_gen_pkg.g_scn_limit_reached
        and    ac.error_number != 0;
        return l_error_count;
    END;

    FUNCTION apply_active_count (
        p_queue_name 	IN     varchar2
    ) RETURN NUMBER IS
        l_active_count 	number := 0;
    BEGIN
        select count(1) into l_active_count
        from   all_apply aa
        where  aa.queue_owner = mis_gen_pkg.g_queue_owner
        and    aa.queue_name = mis_gen_pkg.g_apply_queue_name
        and    aa.status != 'ENABLED';
        return l_active_count;
    END;

  BEGIN
    -- get list of capture processes
    l_capture_name_list := mis_gen_pkg.get_capture_list(p_staging_owner);
    
    l_stopped_count := capture_stop_count(mis_gen_pkg.g_capture_queue_name);
    l_error_count := capture_error_count(mis_gen_pkg.g_capture_queue_name);
    
    IF l_stopped_count < l_capture_name_list.count THEN
   
        -- check apply processes
        IF apply_process_error_count(p_staging_owner,FALSE) > 0 THEN
            -- restart apply since capture was still working
            -- should just stop again if maximum SCN already reached
-- can't do this with ogg so raise exception for now
RAISE_APPLICATION_ERROR (-20001, 'Apply process error detected, cannot restart apply process with OGG.');
--            start_apply(p_staging_owner);
            commit;
        END IF;

        -- wait for capture processes to stop
        FOR i IN 1..l_retry_limit
        LOOP
        
            DBMS_LOCK.SLEEP(mis_gen_pkg.g_sleep1);

            l_stopped_count := capture_stop_count(mis_gen_pkg.g_capture_queue_name);
            EXIT WHEN l_stopped_count = l_capture_name_list.count;
  
            l_error_count := capture_error_count(mis_gen_pkg.g_capture_queue_name);
            EXIT WHEN l_error_count > 0;

        END LOOP;

        IF l_stopped_count = l_capture_name_list.count THEN
            l_continue := TRUE;
        ELSIF l_error_count > 0 THEN
            mis_gen_pkg.log_strm_message(p_staging_owner, 'wait_stop_points',
                             'Capture process error(s) detected ('||l_error_count||').');
        ELSE
            mis_gen_pkg.log_strm_message(p_staging_owner, 'wait_stop_points',
                             'Maximum capture wait exceeded.');
        END IF;

    ELSE -- already full stop
        l_continue := TRUE;
    END IF;
    
    IF l_continue = TRUE THEN
   
        -- check apply processes
        l_active_count := apply_active_count(mis_gen_pkg.g_apply_queue_name);
        
        IF l_active_count > 0 THEN
            -- wait for apply processes to finish
            FOR i IN 1..l_retry_limit
            LOOP
                DBMS_LOCK.SLEEP(mis_gen_pkg.g_sleep1);

                l_active_count := apply_active_count(mis_gen_pkg.g_apply_queue_name);
                EXIT WHEN l_active_count = 0;
            END LOOP;
        END IF;

        l_error_count := apply_process_error_count(p_staging_owner);
        IF l_error_count > 0 THEN
            l_continue := FALSE;
            mis_gen_pkg.log_strm_message(p_staging_owner, 'wait_stop_points',
                             'Apply process error(s) detected ('||l_error_count||').');
        ELSIF l_active_count = 0 THEN
            l_continue := TRUE;
        ELSE
            l_continue := FALSE;
            mis_gen_pkg.log_strm_message(p_staging_owner, 'wait_stop_points',
                             'Maximum apply wait exceeded.');
        END IF;

    END IF;
    
    IF l_continue = TRUE THEN

        -- force checkpoint to reduce backlog (should update captured_scn values but doesn't)
        FOR i in 1..l_capture_name_list.count
        LOOP
            DBMS_CAPTURE_ADM.SET_PARAMETER(l_capture_name_list(i), '_CHECKPOINT_FORCE', 'Y');
        END LOOP;
    
        -- restart capture (forces captured_scn to be updated)
RAISE_APPLICATION_ERROR (-20001, 'Capture process error detected, cannot restart capture process with OGG.');
/*
        BEGIN
            start_capture(p_staging_owner, FALSE);
        EXCEPTION
            WHEN mis_gen_pkg.cannot_alter_process THEN null;
        END;
*/
        -- wait for capture processes to stop (again)
        FOR i IN 1..l_retry_limit
        LOOP
        
            DBMS_LOCK.SLEEP(mis_gen_pkg.g_sleep1);

            l_stopped_count := capture_stop_count(mis_gen_pkg.g_capture_queue_name);
            EXIT WHEN l_stopped_count = l_capture_name_list.count;
  
            l_error_count := capture_error_count(mis_gen_pkg.g_capture_queue_name);
            EXIT WHEN l_error_count > 0;

        END LOOP;

        IF l_stopped_count = l_capture_name_list.count THEN
            l_continue := TRUE;
        ELSIF l_error_count > 0 THEN
            l_continue := FALSE;
            mis_gen_pkg.log_strm_message(p_staging_owner, 'wait_stop_points',
                             'Capture process error(s) detected ('||l_error_count||').');
        ELSE
            l_continue := FALSE;
            mis_gen_pkg.log_strm_message(p_staging_owner, 'wait_stop_points',
                             'Maximum 2nd capture wait exceeded.');
        END IF;

    END IF;
    
    p_continue := l_continue;

    COMMIT;

  EXCEPTION
  
    WHEN OTHERS THEN
        mis_gen_pkg.log_strm_error (p_staging_owner, 'wait_stop_points',
                        p_err_code => SQLCODE, p_text => SQLERRM ||' Error line :' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        ROLLBACK;
        RAISE;

  END;


END MIS_GG_CTRL_PKG;
/

show errors
