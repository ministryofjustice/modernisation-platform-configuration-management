CREATE OR REPLACE PACKAGE BODY MIS_GEN_PKG AS
/*
 *  NOMIS MIS Goldengate code.
 *  
 *  Description:  	This script creates procedures to support
 *                      Oracle Goldengate DML Handlers for Prison-NOMIS release 1.0e.
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
 *			1.1.1	  06/06/07  R. Taylor	Moved table renaming to apply.
 *                                                      Added message logging.
 *			                                Tag LCRs for apply.
 *			1.1.2	  11/06/07  R. Taylor	Added procedures for creating and
 *                                                      dropping capture and apply processes.
 *                                                      Added procedures for handling column
 *                                                      type differences between source and target.
 *			1.1.3	  13/06/07  R. Taylor	Added data type check to capture and
 *                                                      apply startup procedures.
 *			1.1.4	  25/06/07  R. Taylor	Check apply error queue as part of batch
 *                                                      creation; set batch flag for apply errors.
 *                                                      Also check for active capture process.
 *			1.1.5	  02/07/07  R. Taylor	Check and log scn message numbers.
 *                                                      Correct name lengths for capture process.
 *                                                      Add table existence checks to capture and
 *                                                      apply startup procedures.
 *			1.1.6	  11/07/07  R. Taylor	Use low watermark scn for stop_apply logging.
 *                                                      Check for changes to defined primary key columns in
 *                                                      capture transform rather than unique index columns.
 *                                                      Do not check for record existing in apply
 *                                                      transform if no key information is enabled.
 *			1.1.7	  23/07/07  R. Taylor	Ignore all long/lob data types, only capture
 *                                                      LCRs with INSERT/UPDATE/DELETE command type.
 *			1.1.8	  24/07/07  R. Taylor	Restructure apply to allow CLOBs to be processed.
 *			1.0e.9	  17/09/07  R. Taylor	Renumbered for switch from 1.1 to 1.0e.
 *                                                      Redesigned to use DML apply handlers to cope with
 *                                                      multiple key updates expected with offender merge.
 *			1.0e.10	  26/09/07  R. Taylor	Revert to key splitting in capture transform.
 *			1.0e.11	  01/10/07  R. Taylor	Added handling for invalid LOB locators.
 *			1.0e.12	  01/05/08  R. Taylor	Harden input parameter handling.
 *                                                      Call refresh_col_controls from start_capture.
 *			1.0e.13	  05/05/08  P. Godhania	Added log_purge procedure.
 *			1.0e.14	  07/05/08  R. Taylor	Use upper case in get name and table exists functions.
 *			1.0e.15	  20/05/08  R. Taylor	Message logging changes.
 *			1.0e.16	  27/05/08  R. Taylor	Check for queued errors in start_apply.
 *			1.0e.17	  10/06/08  R. Taylor	Retry on timeout in stop_apply/capture.
 *			1.0e.18	  12/06/08  R. Taylor	Set batch error_flag to N on apply completion.
 *                                                      Sleep before retry in stop_apply/capture. 
 *			1.0e.19	  15/08/08  R. Taylor	Modify set_col_differences to detect target columns
 *                                                      that do not occur in source table. 
 *			1.0e.20	  15/08/08  R. Taylor	Always convert LONG columns to LOB in capture
 *                                                      transformation to avoid errors from apply process. 
 *			1.0e.21	  01/09/08  R. Taylor	Store key column names against STRM_TAB_CONTROL.
 *                                                      Redesign apply handlers to use distinct procedures for
 *                                                      each table. Generate procedures in set_apply_handlers.
 *                                                      Get key columns from control record in capture transform.
 *			1.0e.22	  10/09/08  R. Taylor	Log message create time in stop_apply.
 *                                                      Add get_capture_nrs_name function.
 *                                                      Add reload_tables procedure.
 *			1.0e.23	  22/09/08  R. Taylor	Add calls to refresh_col_controls, refresh_apply_keys,
 *                                                      set_apply_handlers to start_apply (parameter-driven) and
 *                                                      remove calls from create_new_batch.
 *                                                      Modify apply_handler_user not to set batch error
 *                                                      flag for invalid_lob_locator exceptions.
 *			1.0e.24	  23/09/08  R. Taylor	Use same local procedure convert_lcr_to_insert in capture
 *                                                      transform key splitting and apply handler processing.
 *			1.0e.25	  24/09/08  R. Taylor	Increase plsql buffer length in reload_table and
 *                                                      column list functions.
 *			1.0e.26	  17/10/08  R. Taylor	Expose log_strm_error procedure (previously local).
 *			1.0e.27	  19/12/08  R. Taylor	Added stop point handling.
 *                                                      Modified log_purge to check file status before deletion.
 *			1.0e.28	  15/01/09  R. Taylor	Check start_scn when setting stop points.
 *			1.0e.29	  19/01/09  R. Taylor	Ensure apply running during wait for stop points.
 *                                                      Check for apply process errors (as well as queue entries).
 *			1.0e.30	  22/01/09  R. Taylor	Add function get_scn_timestamp. Use in create_new_batch.
 *			1.0e.31	  23/01/09  R. Taylor	Modified set_stop_points to reference staged_start_datetime.
 *                                                      Remove get_scn_timestamp function as cannot invoke
 *                                                      scn_to_timestamp across database link parameter.
 *                                                      Call set_stop_points at end of create_new_batch and
 *                                                      return output parameter.
 *                                                      Modify apply_hi_scn to default low watermark if high is null.
 *                                                      Add apply_message_date and capture_log_date functions.
 *			1.0e.32	  26/01/09  R. Taylor	Remove apply_message_date function.
 *                                                      Use capture_log_date for staged end date in create_new_batch.
 *			1.0e.33	  04/03/09  R. Taylor	Defect 14424 - modify capture control for stop points.
 *                                                      Raise application errors with defined text.
 *                                                      Trap empty STRM_TAB_CONTROL when checking tables.
 *			1.0e.34	  19/03/09  R. Taylor	Defect 14424 - modify capture control for stop points.
 *                                                      Correct error message in check_table_existence.
 *			1.0e.35	  22/03/09  R. Taylor	Add function get_scn_timestamp. Use in create_new_batch.
 *			                                Modify apply_hi_scn to check capture if no apply info.
 *                                                      Add unload_tables procedure.
 *			1.0e.36	  06/08/09  R. Taylor	Add procedure set_capture_pos_rules. Use in start_capture.
 *			1.0e.37	  14/08/09  R. Taylor	Modify use of where clauses in apply handler
 * 							to use bind variables.
 *			1.0e.38	  07/10/09  R. Taylor	Modify command type checking in capture transformation.
 *			1.0e.39	  14/10/09  R. Taylor	Call update_tab_stats procedure from check_table_existence.
 *			1.0e.40   15/10/09  R. Taylor	Modify setting of bind variables in apply handler.
 *			1.0e.41   30/11/09  R. Taylor	Revert apply handler to remove bind variable use.
 *			1.0e.42   14/12/09  R. Taylor	Revert capture transform command type checking.
 *			1.0e.43   19/01/10  R. Taylor	Trap embedded quotes in apply where clause.
 *			1.0e.44   13/01/10  R. Taylor	Rewrite apply handling to handle some execute errors to
 * 							achieve INSERT/UPDATE switching for batches without select.
 *			1.0e.45   19/01/10  R. Taylor	Reinstate capture transform command type checking changes.
 *			1.0e.46   21/01/10  R. Taylor	Always try insert first in apply handler.
 *			1.0e.47   21/01/10  R. Taylor	Pass batch number into apply handler.
 *			1.0e.48   08/02/10  R. Taylor	Convert schema name in capture transform.
 *			1.0e.49   15/02/10  R. Taylor	Split positive capture rules out by table.
 *                                                      Add procedure clear_capture_pos_rules.
 *			1.0e.50	  24/02/10  R. Taylor	Use upper case in update table stats procedure.
 *                                                      Explicitly set instantiation scn for new tables.
 *			1.0e.51	  01/03/10  R. Taylor	Specify command types in positive capture rules.
 *			1.0e.52	  11/03/10  R. Taylor	Added get_version function.
 *			1.0e.53	  06/08/10  R. Taylor	Modified for Oracle 11gR1.
 *			1.0e.54	  12/08/10  R. Taylor	Updated to allow for normal and reference target tables
 *                                                      from a common source table.
 *			1.0e.55	  02/09/10  R. Taylor	Allow for missing key columns.
 *			1.0e.56	  08/09/10  R. Taylor	Adjust LOB table rule conditions.
 *			1.0e.57	  15/09/10  R. Taylor	Change REF table exception handling.
 *                                                      Added log_apply procedure.
 *			1.0e.58	  16/09/10  R. Taylor	Change mis_scn handling in unload_tables.
 *			1.0e.59	  01/05/13  R. Taylor	Added purge_records procedure (defect 19143).
 */

  FUNCTION strip_input (p_str varchar2, p_len number)
  RETURN varchar2 RESULT_CACHE IS
  -- function strip_input
  -- will remove single quotes and comment characters from input string
  BEGIN
    return substr(replace(translate(p_str,'''-/','***'),'*',''),1,p_len);
  END;


  PROCEDURE log_strm_error (
    p_staging_owner 	IN     varchar2,
    p_location 		IN     varchar2 DEFAULT 'MIS_GEN_PKG',
    p_src_db 		IN     varchar2 DEFAULT NULL,
    p_src_owner 	IN     varchar2 DEFAULT NULL,
    p_src_table 	IN     varchar2 DEFAULT NULL,
    p_tgt_table 	IN     varchar2 DEFAULT NULL,
    p_batch_id 		IN     number   DEFAULT NULL,
    p_err_code 		IN     number   DEFAULT NULL,
    p_text 	 	IN     varchar2 DEFAULT NULL
  ) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  -- packaged procedure log_strm_error
  -- will insert entries in p_staging_owner.STRM_ERROR_LOG
    l_plsql 		varchar2(2000);
    l_staging_owner	varchar2(30) := strip_input(p_staging_owner,30);
    l_text 		varchar2(4000) := substr(p_text,1,4000);
  BEGIN

    l_plsql := 'insert into ' || l_staging_owner || '.STRM_ERROR_LOG (' ||
               'ERROR_DATETIME,ERROR_LOCATION,SRC_DB,SRC_OWNER,' ||
               'SRC_TABLE,TGT_TABLE,MIS_BATCH_ID,ERROR_CODE,ERROR_TEXT) VALUES (' ||
               ':timestamp,:ERROR_LOCATION,:SRC_DB,:SRC_OWNER,' ||
               ':SRC_TABLE,:TGT_TABLE,:MIS_BATCH_ID,:ERROR_CODE,:ERROR_TEXT)';

    execute immediate l_plsql
    using systimestamp,p_location,p_src_db,p_src_owner,p_src_table,
          p_tgt_table,p_batch_id,p_err_code,l_text;

    commit;

  --EXCEPTION

    --WHEN OTHERS THEN null; -- what to do?

  END;

  PROCEDURE log_strm_message (
    p_staging_owner 	IN     varchar2,
    p_location 		IN     varchar2,
    p_text 	 	IN     varchar2
  ) IS
  -- packaged procedure log_strm_message
  -- will insert entries in p_staging_owner.STRM_ERROR_LOG
  BEGIN

    log_strm_error (p_staging_owner, p_location,
                    p_err_code => 0, p_text => p_text);

  END;


  PROCEDURE log_strm_debug (
    p_staging_owner 	IN     varchar2,
    p_location 		IN     varchar2,
    p_text 	 	IN     varchar2,
    p_threshold 	IN     number DEFAULT 0
  ) IS
  -- packaged procedure log_strm_debug
  -- will insert entries in p_staging_owner.STRM_ERROR_LOG
  BEGIN

    IF g_debug > p_threshold THEN
        log_strm_message (p_staging_owner, p_location, p_text);
    END IF;

  END;

  FUNCTION get_queue_name(
    p_staging_owner IN varchar2
  ) RETURN varchar2 RESULT_CACHE
  IS
  -- packaged function get_queue_name returns the queue name
  -- for the supplied staging table owner
    v_length 		number := length(p_staging_owner);
  BEGIN
    IF v_length > 24 THEN -- leave room to use queue name in job name
        return 'OGG$Q_' || substr(upper(p_staging_owner), v_length-23, 24);
    ELSE
        return 'OGG$Q_' || upper(p_staging_owner);
    END IF;
  END;



  FUNCTION get_capture_list(
    p_staging_owner 	IN     varchar2 DEFAULT NULL
  ) RETURN capture_list IS
  -- local procedure get_capture_list returns a list of all capture processes
  -- or those associated with a particular staging table owner (if supplied)

    v_plsql			    varchar2(2000); 
    v_queue_name		varchar2(30);
    v_capture_name_list capture_list := null;

  BEGIN

    -- get list of capture processes
    v_plsql := 'select capture_name ' ||
                 'from all_capture ' ||
                'where queue_owner = :queue_owner';
    IF p_staging_owner IS NULL THEN
        execute immediate v_plsql
        bulk collect into v_capture_name_list
        using g_queue_owner;
    ELSE
        v_queue_name := get_queue_name(p_staging_owner);
        v_plsql := v_plsql ||
                 ' and queue_name = :queue_name';

        execute immediate v_plsql
        bulk collect into v_capture_name_list
        using g_queue_owner, v_queue_name;
    END IF;

    return v_capture_name_list;

  EXCEPTION

    WHEN OTHERS THEN
        log_strm_error (p_staging_owner, 'get_capture_list',
                        p_err_code => SQLCODE, p_text => SQLERRM ||' Error line :' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;

  END;



  FUNCTION get_apply_list(
    p_staging_owner 	IN     varchar2 DEFAULT NULL
  ) RETURN apply_list IS
  -- local procedure get_apply_list returns a list of all apply processes
  -- or those associated with a particular staging table owner (if supplied)

    v_plsql			    varchar2(2000); 
    v_queue_name		varchar2(30) := get_queue_name(p_staging_owner);
    v_apply_name_list 	apply_list := null;

  BEGIN

    -- get list of apply processes
    v_plsql := 'select apply_name ' ||
                 'from all_apply ' ||
                'where queue_owner = :queue_owner';
    IF p_staging_owner IS NULL THEN
        execute immediate v_plsql
        bulk collect into v_apply_name_list
        using g_queue_owner;
    ELSE
        v_plsql := v_plsql ||
                 ' and queue_name = :queue_name';

        execute immediate v_plsql
        bulk collect into v_apply_name_list
        using g_queue_owner, v_queue_name;
    END IF;

    return v_apply_name_list;

  EXCEPTION

    WHEN OTHERS THEN
        log_strm_error (p_staging_owner, 'get_apply_list',
                        p_err_code => SQLCODE, p_text => SQLERRM ||' Error line :' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;

  END;

  FUNCTION object_list_to_comma(
        p_object_list	 	IN     object_list
    ) RETURN varchar2
  IS
  -- packaged function object_list_to_comma returns a comma-separated string
  -- containing values from a object_list type
    l_object_str        varchar2(4000) := '';
  BEGIN
    IF p_object_list IS NULL THEN
        return '';
    ELSIF p_object_list.count = 0 THEN
        return '';
    ELSE
        l_object_str := p_object_list(1);
        FOR i in 2..p_object_list.count
        LOOP
            l_object_str := l_object_str || ',' || p_object_list(i);
        END LOOP;
        return l_object_str;
    END IF;
  END;

  FUNCTION comma_to_object_list(
        p_object_str	 	IN     varchar2
    ) RETURN object_list RESULT_CACHE
  IS
  -- packaged function comma_to_object_list returns a object_list type
  -- containing values from a comma-separated string
  -- list will contain at least one element (even if that element is null)
    l_object_list       object_list;
    l_comma_pos 	number;
    l_object_str	varchar2(4000) := strip_input(p_object_str,4000);
  BEGIN
    l_comma_pos := instr(l_object_str,',',-1);
    IF l_comma_pos > 0 THEN
        l_object_list := comma_to_object_list(substr(l_object_str,1,l_comma_pos-1));
    ELSE
        l_object_list := object_list();
    END IF;
    l_object_list.EXTEND;
    l_object_list(l_object_list.LAST) := substr(l_object_str,l_comma_pos+1);
    return l_object_list;
  END;



END MIS_GEN_PKG;
/

show errors
