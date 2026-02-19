CREATE OR REPLACE PACKAGE BODY MIS_DML_PKG AS
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
 *			1.0e.26	  17/10/08  R. Taylor	Expose mis_gen_pkg.log_strm_error procedure (previously local).
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

  FUNCTION get_version RETURN varchar2 IS
  -- packaged function get_version
  -- will return a VARCHAR2 string containing a package version number
  BEGIN
    return g_version;
  END;


  FUNCTION convert_anydata_to_varchar2 (
    p_any_val in sys.anydata
  ) RETURN varchar2 IS
  -- packaged function convert_anydata_to_varchar2
  -- will convert a SYS.ANYDATA record to a VARCHAR2 string

    v_varchar2_val 	varchar2(32767);   
    v_type 		varchar2(32) := '';   
    v_rtn 		number;

  BEGIN   
    IF p_any_val is null THEN
        return NULL;
    END IF;
  
    v_type := lower(p_any_val.gettypename());

    CASE v_type   
            --alphabetical list of currently used types   
            when 'sys.char' then   
                v_rtn := p_any_val.getchar(v_varchar2_val);   
            when 'sys.date' then   
                v_rtn := p_any_val.getdate(v_varchar2_val);   
            when 'sys.number' then   
                v_rtn := p_any_val.getnumber(v_varchar2_val);   
            when 'sys.raw' then   
                v_varchar2_val := '<binary data>';   
            when 'sys.timestamp' then   
                v_rtn := p_any_val.gettimestamp(v_varchar2_val);   
            when 'sys.varchar2' then
                v_rtn := p_any_val.getvarchar2(v_varchar2_val);   
            else
                RAISE_APPLICATION_ERROR(g_MIS_STREAMS_DATA_EXCEPTION,'Data type not handled.');
    END CASE;

    return substr(v_varchar2_val, 1, 2000);

  END;

  FUNCTION convert_anydata_to_date (
    p_any_val in sys.anydata
  ) RETURN date IS
  -- packaged function convert_anydata_to_date
  -- will convert a SYS.ANYDATA record to a date value

    v_date_val 		date := null;   
    v_type 		varchar2(32) := '';   
    v_rtn 		number;

  BEGIN   
    IF p_any_val is null THEN
        return NULL;
    END IF;
  
    v_type := lower(p_any_val.gettypename());

    CASE v_type   
            --alphabetical list of currently used types   
            when 'sys.char' then   
                v_rtn := p_any_val.getchar(v_date_val);   
            when 'sys.date' then   
                v_rtn := p_any_val.getdate(v_date_val);
            when 'sys.timestamp' then   
                v_rtn := p_any_val.gettimestamp(v_date_val);
            when 'sys.timestamp_with_timezone' then
                v_rtn := p_any_val.gettimestamptz(v_date_val);
            when 'sys.timestamp_with_ltz' then
                v_rtn := p_any_val.gettimestampltz(v_date_val);
            when 'sys.varchar2' then
                v_rtn := p_any_val.getvarchar2(v_date_val);   
            else
                RAISE_APPLICATION_ERROR(g_MIS_STREAMS_DATA_EXCEPTION,'Data type not handled.');
    END CASE;

    return v_date_val;

  END;


  FUNCTION get_queue_name(
    p_staging_owner IN varchar2
  ) RETURN varchar2 RESULT_CACHE
  IS
  -- packaged function get_queue_name returns the streams queue name
  -- for the supplied staging table owner
    v_length 		number := length(p_staging_owner);
  BEGIN
    IF v_length > 24 THEN -- leave room to use queue name in job name
        return 'Q_' || substr(upper(p_staging_owner), v_length-23, 24);
    ELSE
        return 'Q_' || upper(p_staging_owner);
    END IF;
  END;

  FUNCTION get_capture_name(
    p_source_owner IN varchar2
  ) RETURN varchar2 RESULT_CACHE
  IS
  -- packaged function get_capture_name returns the streams capture process name
  -- for the supplied source table owner
    v_length 		number := length(p_source_owner);
  BEGIN
    IF v_length > 22 THEN
        return substr(upper(p_source_owner), v_length-21, 22)||'_CAPTURE';
    ELSE
        return upper(p_source_owner)||'_CAPTURE';
    END IF;
  END;

  FUNCTION get_capture_rs_name(
    p_source_owner IN varchar2
  ) RETURN varchar2 RESULT_CACHE
  IS
  -- packaged function get_capture_rs_name returns the streams capture rule set name
  -- for the supplied source table owner
    v_length 		number := length(p_source_owner);
  BEGIN
    IF v_length > 22 THEN
        return 'RS_C_'||substr(upper(p_source_owner), v_length-21, 22);
    ELSE
        return 'RS_C_'||upper(p_source_owner);
    END IF;
  END;

  FUNCTION get_capture_nrs_name(
    p_source_owner IN varchar2
  ) RETURN varchar2 RESULT_CACHE
  IS
  -- packaged function get_capture_nrs_name returns the streams capture negative
  -- rule set name for the supplied source table owner
    v_length 		number := length(p_source_owner);
  BEGIN
    IF v_length > 21 THEN
        return 'NRS_C_'||substr(upper(p_source_owner), v_length-20, 21);
    ELSE
        return 'NRS_C_'||upper(p_source_owner);
    END IF;
  END;

  FUNCTION get_apply_name(
    p_source_owner IN varchar2
  ) RETURN varchar2 RESULT_CACHE
  IS
  -- packaged function get_apply_name returns the streams apply process name
  -- for the supplied source table owner
    v_length 		number := length(p_source_owner);
  BEGIN
    IF v_length > 22 THEN
        return substr(upper(p_source_owner), v_length-21, 22)||'_APPLY';
    ELSE
        return upper(p_source_owner)||'_APPLY';
    END IF;
  END;

  FUNCTION get_apply_rs_name(
    p_source_owner IN varchar2
  ) RETURN varchar2 RESULT_CACHE
  IS
  -- packaged function get_apply_rs_name returns the streams apply rule set name
  -- for the supplied source table owner
    v_length 		number := length(p_source_owner);
  BEGIN
    IF v_length > 22 THEN
        return 'RS_A_'||substr(upper(p_source_owner), v_length-21, 22);
    ELSE
        return 'RS_A_'||upper(p_source_owner);
    END IF;
  END;

  FUNCTION get_xform_func_name(
        p_tgt_owner 		IN     VARCHAR2,
        p_tab_seq	 	IN     NUMBER
    ) RETURN varchar2 RESULT_CACHE
  IS
  -- packaged function get_xfrom_func_name returns the capture transformation name
  -- for the supplied target table
    v_length 		number := length(p_tgt_owner);
  BEGIN
    IF v_length > 18 THEN
        return substr(upper(p_tgt_owner), v_length-17, 18) ||
                '_XFORM_'||mod(p_tab_seq,100000);
    ELSE
        return upper(p_tgt_owner)||'_XFORM_'||mod(p_tab_seq,100000);
    END IF;
  END;

  FUNCTION get_dml_proc_name(
        p_tgt_owner 	IN     VARCHAR2,
        p_tab_seq	 	IN     NUMBER,
        p_key_columns	IN     VARCHAR2
    ) RETURN varchar2 RESULT_CACHE
  IS
  -- packaged function get_dml_proc_name returns the streams dml handler name
  -- for the supplied target table (includes hash of key column names)
    v_length 		number := length(p_tgt_owner);
  BEGIN
    IF v_length > 14 THEN
        return substr(upper(p_tgt_owner), v_length-13, 14) ||
                '_DML_'||mod(p_tab_seq,100000)||'_'||DBMS_UTILITY.GET_HASH_VALUE(p_key_columns,0,100000);
    ELSE
        return upper(p_tgt_owner) ||
                '_DML_'||mod(p_tab_seq,100000)||'_'||DBMS_UTILITY.GET_HASH_VALUE(p_key_columns,0,100000);
    END IF;
  END;

  FUNCTION object_list_to_comma(
        p_object_list	 	IN     mis_gen_pkg.object_list
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
    ) RETURN mis_gen_pkg.object_list RESULT_CACHE
  IS
  -- packaged function comma_to_object_list returns a object_list type
  -- containing values from a comma-separated string
  -- list will contain at least one element (even if that element is null)
    l_object_list   mis_gen_pkg.object_list;
    l_comma_pos 	number;
    l_object_str	varchar2(4000) := mis_gen_pkg.strip_input(p_object_str,4000);
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


  FUNCTION get_capture_list(
    p_staging_owner 	IN     varchar2 DEFAULT NULL
  ) RETURN mis_gen_pkg.capture_list IS
  -- local procedure get_capture_list returns a list of all capture processes
  -- or those associated with a particular staging table owner (if supplied)

    v_plsql			    varchar2(2000); 
    v_queue_name		varchar2(30);
    v_capture_name_list mis_gen_pkg.capture_list := null;

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
        mis_gen_pkg.log_strm_error (p_staging_owner, 'get_capture_list',
                        p_err_code => SQLCODE, p_text => SQLERRM);
        RAISE;

  END;

  PROCEDURE set_capture_pos_rules (
    p_tgt_owner         IN     varchar2,
    p_src_db 		IN     VARCHAR2,
    p_src_owner 	IN     VARCHAR2
  ) IS
  -- packaged procedure set_capture_pos_rules
  -- will set positive capture rules based on contents of p_tgt_owner.STRM_TAB_CONTROL

    l_streams_name	varchar2(30) := get_capture_name(p_src_owner);
    l_queue_name	varchar2(30) := get_queue_name(p_tgt_owner);
    l_rule_name_dml	varchar2(65);
    l_rule_name_ddl	varchar2(65);
    l_del_rule_list 	rule_list;
    l_add_rule_list 	rule_list;
    l_src_table_list 	object_list;
    l_tgt_table_list 	object_list;
    l_tgt_table_str	varchar2(400);
    l_proc_flag_list	object_list;
    l_proc_flag_str	varchar2(400);
    l_tab_seq_list      tab_seq_list;
    l_key_columns_list	key_col_list;
    l_rule_comment_list	string_list;
    l_xform_name 	varchar2(30);
    l_rule_comment 	varchar2(2000);
    l_and_condition 	varchar2(200);
    l_and_cond_in_set 	varchar2(200);
    l_scn 		number := 0;
    l_plsql 		varchar2(4000);

  BEGIN

    -- determine rules to be deleted after creating new ones
    l_plsql := 'select rule_name ' ||
                'from (select r.rule_name, c.src_table ' ||
                        'from ' || p_tgt_owner || '.STRM_TAB_CONTROL c, ALL_STREAMS_RULES r ' ||
                       'where r.STREAMS_TYPE = ''CAPTURE'' ' ||
                         'and r.STREAMS_NAME = :streams_name ' ||
                         'and r.RULE_SET_TYPE = ''POSITIVE'' ' ||
                         'and r.SOURCE_DATABASE = :src_db ' ||
                         'and r.SCHEMA_NAME = :src_owner ' ||
                         'and c.src_db (+) = r.SOURCE_DATABASE ' ||
                         'and c.src_owner (+) = r.SCHEMA_NAME ' ||
                         'and c.src_table (+) = r.OBJECT_NAME) rules ' ||
                'where src_table is null';
    execute immediate l_plsql bulk collect into l_del_rule_list
    using l_streams_name, p_src_db, p_src_owner;

    -- determine source table names to add rules for
    l_plsql := 'select DISTINCT c.src_table, sr.rule_name, r.rule_comment ' ||
                 'from ALL_RULES r, ALL_STREAMS_RULES sr, ' || p_tgt_owner || '.STRM_TAB_CONTROL c ' ||
                'where r.RULE_OWNER (+) = sr.RULE_OWNER ' ||
                  'and r.RULE_NAME (+) = sr.RULE_NAME ' ||
                  'and sr.STREAMS_TYPE (+) = ''CAPTURE'' ' ||
                  'and sr.STREAMS_NAME (+) = :streams_name ' ||
                  'and sr.RULE_SET_TYPE (+) = ''POSITIVE'' ' ||
                  'and sr.SOURCE_DATABASE (+) = c.src_db ' ||
                  'and sr.SCHEMA_NAME (+) = c.src_owner ' ||
                  'and sr.OBJECT_NAME (+) = c.src_table ' ||
                  'and c.src_db = :src_db ' ||
                  'and c.src_owner = :src_owner';
    execute immediate l_plsql
    bulk collect into l_src_table_list, l_add_rule_list, l_rule_comment_list
    using l_streams_name, p_src_db, p_src_owner;
    
    -- get SCN value for table instantiation
    select nvl(ac.start_scn, ac.first_scn) into l_scn
    from   ALL_CAPTURE ac
    where  capture_name = l_streams_name;

    -- add and configure positive capture rules
    FOR i IN 1..l_src_table_list.count
    LOOP
        -- determine target table names to add to transform function
        l_plsql := 'select c.tgt_table, c.key_columns, c.proc_flags, c.tab_seq ' ||
                    'from ' || p_tgt_owner || '.STRM_TAB_CONTROL c ' ||
                    'where c.src_table = :src_table ' ||
                      'and c.src_db = :src_db ' ||
                      'and c.src_owner = :src_owner';
        execute immediate l_plsql
        bulk collect into l_tgt_table_list, l_key_columns_list, l_proc_flag_list, l_tab_seq_list
        using l_src_table_list(i), p_src_db, p_src_owner;

        -- check target key column definitions
        FOR j IN 2..l_key_columns_list.count LOOP
            IF (l_key_columns_list(j) != l_key_columns_list(1)) THEN
                RAISE_APPLICATION_ERROR
                    (g_MIS_STREAMS_EXCEPTION, 'Target tables have different key columns ' ||
                     'for source table ' || l_src_table_list(i) || '.');
            END IF;
        END LOOP;

        -- create capture transform function for table(s)
        l_xform_name := get_xform_func_name(p_tgt_owner, l_tab_seq_list(1));

        l_tgt_table_str := object_list_to_comma(l_tgt_table_list);
        l_proc_flag_str := object_list_to_comma(l_proc_flag_list);

        l_plsql := 'CREATE OR REPLACE FUNCTION ' || l_xform_name ||
                '(p_in_anydata IN sys.anydata) RETURN ANYDATA_ARRAY IS ' ||
            'BEGIN ' ||
                'RETURN mis_DML_PKG.capture_rule_row_xform_user' ||
                '(p_in_anydata,'''||p_tgt_owner||''','''||l_tgt_table_str||''','''||
                  l_key_columns_list(1)||''','''||l_proc_flag_str||'''); ' ||
            'END;';
        dbms_utility.exec_ddl_statement(l_plsql);

        -- handle table processing flags
        l_rule_comment := g_capture_pr_tab_comment ||
            trim(l_proc_flag_str) || ') FOR ' || l_tgt_table_str;
        l_and_cond_in_set := '''INSERT'',''UPDATE'',''DELETE''';
        IF (instr(l_proc_flag_str, 'LONG') > 0) THEN
            l_and_cond_in_set := l_and_cond_in_set || ',''LONG WRITE''';
        END IF;
        IF (instr(l_proc_flag_str, 'LOB') > 0) THEN
            l_and_condition := NULL;
        ELSE
            l_and_condition :=
                ':lcr.get_command_type() IN (' || l_and_cond_in_set || ')';
        END IF;

        IF l_add_rule_list(i) IS NULL THEN
            -- add positive capture rule for new source table
            dbms_streams_adm.add_table_rules(
              table_name => p_src_owner||'.'||l_src_table_list(i),
              streams_type => 'capture',
              streams_name => l_streams_name,
              queue_name => l_queue_name,
              include_dml => true,
              include_ddl => false,
              include_tagged_lcr => true,
              source_database => p_src_db,
              dml_rule_name => l_rule_name_dml,
              ddl_rule_name => l_rule_name_ddl,
              inclusion_rule => true,
              and_condition => l_and_condition
            );
            -- now use l_rule_name_dml here to set transform
            DBMS_STREAMS_ADM.SET_RULE_TRANSFORM_FUNCTION(
              rule_name => l_rule_name_dml,
              transform_function => l_xform_name);
	          -- set comment for rule
            dbms_rule_adm.alter_rule
              (l_rule_name_dml, rule_comment=>l_rule_comment);
            -- set instantiation scn for new source table
            dbms_apply_adm.set_table_instantiation_scn(
            source_object_name => p_src_owner||'.'||l_src_table_list(i),
            source_database_name => p_src_db,
            instantiation_scn => l_scn);
        ELSIF (l_rule_comment_list(i) IS NULL) OR (l_rule_comment_list(i) <> l_rule_comment) THEN
            -- replace positive capture rule for existing source table
            dbms_streams_adm.add_table_rules(
              table_name => p_src_owner||'.'||l_src_table_list(i),
              streams_type => 'capture',
              streams_name => l_streams_name,
              queue_name => l_queue_name,
              include_dml => true,
              include_ddl => false,
              include_tagged_lcr => true,
              source_database => p_src_db,
              dml_rule_name => l_rule_name_dml,
              ddl_rule_name => l_rule_name_ddl,
              inclusion_rule => true,
              and_condition => l_and_condition
            );
            -- now use l_rule_name_dml here to set transform
            DBMS_STREAMS_ADM.SET_RULE_TRANSFORM_FUNCTION(
              rule_name => l_rule_name_dml,
              transform_function => l_xform_name);
      	    -- set comment for new rule
            dbms_rule_adm.alter_rule
              (l_rule_name_dml, rule_comment=>l_rule_comment);
            -- drop old rule
            dbms_rule_adm.DROP_RULE(l_add_rule_list(i), TRUE);
        ELSE
            -- use l_add_rule_list(i) here to reset transform (just in case)
            DBMS_STREAMS_ADM.SET_RULE_TRANSFORM_FUNCTION(
              rule_name => l_add_rule_list(i),
              transform_function => l_xform_name);
      	END IF;
    END LOOP;

    -- drop old rules
    FOR i IN 1..l_del_rule_list.count LOOP
        dbms_rule_adm.DROP_RULE(l_del_rule_list(i), TRUE);
    END LOOP;

  EXCEPTION

    WHEN OTHERS THEN
        mis_gen_pkg.log_strm_error (p_tgt_owner, 'set_capture_pos_rules',
                        p_err_code => SQLCODE, p_text => SQLERRM);
        RAISE;

  END;

  PROCEDURE clear_capture_pos_rules (
    p_tgt_owner         IN     varchar2,
    p_src_owner 	IN     VARCHAR2
  ) IS
  -- packaged procedure clear_capture_pos_rules
  -- will drop positive capture rules and their transformation functions

    l_streams_name	varchar2(30) := get_capture_name(p_src_owner);
    l_queue_name	varchar2(30) := get_queue_name(p_tgt_owner);
    l_rule_name_dml	varchar2(65);
    l_rule_name_ddl	varchar2(65);
    l_del_rule_list 	rule_list;
    l_xform_list 	string_list;
    l_plsql 		varchar2(2000);

  BEGIN

    -- determine rules to be deleted
    l_plsql := 'select r.rule_name, f.TRANSFORM_FUNCTION_NAME ' ||
                 'from ALL_STREAMS_TRANSFORM_FUNCTION f, ALL_STREAMS_RULES r ' ||
                'where r.STREAMS_TYPE = ''CAPTURE'' ' ||
                  'and r.STREAMS_NAME = :streams_name ' ||
                  'and r.RULE_SET_TYPE = ''POSITIVE'' ' ||
                  'and r.SCHEMA_NAME = :src_owner ' ||
                  'and f.RULE_OWNER (+) = r.RULE_OWNER ' ||
                  'and f.RULE_NAME (+) = r.rule_name';
    execute immediate l_plsql
    bulk collect into l_del_rule_list, l_xform_list
    using l_streams_name, p_src_owner;

    -- drop old rules
    FOR i IN 1..l_del_rule_list.count
    LOOP
        dbms_rule_adm.DROP_RULE(l_del_rule_list(i), TRUE);
        -- drop transformation functions for rules
        IF l_xform_list(i) IS NOT NULL THEN
            BEGIN
                l_plsql := 'DROP FUNCTION ' || l_xform_list(i);
                dbms_utility.exec_ddl_statement(l_plsql);
            EXCEPTION WHEN OTHERS THEN null;
            END;
      	END IF;
    END LOOP;

  EXCEPTION

    WHEN OTHERS THEN
        mis_gen_pkg.log_strm_error (p_tgt_owner, 'clear_capture_pos_rules',
                        p_err_code => SQLCODE, p_text => SQLERRM);
        RAISE;

  END;


  FUNCTION capture_inactive_count(
    p_staging_owner 	IN     varchar2 DEFAULT NULL
  ) RETURN number
  IS
  -- local function capture_inactive_count returns the number of capture processes
  -- for a particular staging table owner (if supplied) that are not enabled

    v_plsql			varchar2(2000); 
    v_capture_name_list 	capture_list;
    v_status 			varchar2(20);
    v_err_number 		number;
    v_err_total 		number := 0;
    v_first_scn 		number;
    v_captured_scn 		number;

  BEGIN

    -- get list of capture processes
    v_capture_name_list := get_capture_list(p_staging_owner);

    v_plsql := 'select status, error_number, first_scn, captured_scn ' ||
                 'from dba_capture ' ||
                'where capture_name = :capture_name';

    -- count capture process errors
    FOR i IN 1..v_capture_name_list.count
    LOOP
        execute immediate v_plsql
        into v_status, v_err_number, v_first_scn, v_captured_scn
        using v_capture_name_list(i);
        IF v_status = 'ENABLED' THEN
            mis_gen_pkg.log_strm_debug (p_staging_owner, 'capture_inactive_count',
                              'Capture process ' || v_capture_name_list(i) ||
                              ' is ENABLED (captured_scn=' || v_captured_scn ||
                              ', first_scn=' || v_first_scn || ').', -1);
        ELSIF v_err_number = g_scn_limit_reached THEN
            mis_gen_pkg.log_strm_message (p_staging_owner, 'capture_inactive_count',
                              'Capture process ' || v_capture_name_list(i) ||
                              ' is ' || v_status || ' because SCN limit reached (' ||
                              'captured_scn=' || v_captured_scn ||
                              ', first_scn=' || v_first_scn || ').');
        ELSE
            v_err_total := v_err_total + 1;
            mis_gen_pkg.log_strm_message (p_staging_owner, 'capture_inactive_count',
                              'Capture process ' || v_capture_name_list(i) ||
                              ' is ' || v_status || ' (error_number=' || nvl(v_err_number,0) ||
                              ', captured_scn=' || v_captured_scn ||
                              ', first_scn=' || v_first_scn || ').');
        END IF;
    END LOOP;

    return v_err_total;

  EXCEPTION

    WHEN OTHERS THEN
        mis_gen_pkg.log_strm_error (p_staging_owner, 'capture_inactive_count',
                        p_err_code => SQLCODE, p_text => SQLERRM);
        RAISE;

  END;

  FUNCTION capture_log_date(
    p_staging_owner 	IN     varchar2,
    p_scn 		IN     number
  ) RETURN date IS
  -- local function capture_log_date returns the next date (end of log) for logs
  -- registered to capture processes associated with a particular staging table owner
  -- containing data for a given SCN

    v_plsql			varchar2(2000); 
    v_capture_name_list 	capture_list;
    v_next_time 		date;
    v_log_date 			date := null;

  BEGIN

    -- get list of capture processes
    v_capture_name_list := get_capture_list(p_staging_owner);

    v_plsql := 'select min(next_time) ' ||
                 'from dba_registered_archived_log ' ||
                'where consumer_name = :capture_name ' ||
                  'and :scn between first_scn and next_scn';

    -- count capture process errors
    FOR i IN 1..v_capture_name_list.count
    LOOP
        execute immediate v_plsql
        into v_next_time
        using v_capture_name_list(i), p_scn;
        v_log_date := greatest(nvl(v_log_date,v_next_time),v_next_time);
    END LOOP;

    return v_log_date;

  EXCEPTION
    WHEN OTHERS THEN
        mis_gen_pkg.log_strm_error (p_staging_owner, 'capture_log_date',
                        p_err_code => SQLCODE, p_text => SQLERRM);
        RAISE;
  END;


  FUNCTION get_apply_list(
    p_staging_owner 	IN     varchar2 DEFAULT NULL
  ) RETURN apply_list IS
  -- local procedure get_apply_list returns a list of all apply processes
  -- or those associated with a particular staging table owner (if supplied)

    v_plsql			varchar2(2000); 
    v_queue_name		varchar2(30) := get_queue_name(p_staging_owner);
    v_apply_name_list 		apply_list := null;

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
        mis_gen_pkg.log_strm_error (p_staging_owner, 'get_apply_list',
                        p_err_code => SQLCODE, p_text => SQLERRM);
        RAISE;

  END;


  FUNCTION apply_error_count(
    p_staging_owner 	IN     varchar2 DEFAULT NULL
  ) RETURN number
  IS
  -- local function apply_error_count returns the number of error messages queued
  -- for apply processes associated with a particular staging table owner (if supplied)

    v_plsql			varchar2(2000); 
    v_apply_name_list 		apply_list;
    v_err_count 		number;
    v_err_total 		number := 0;

  BEGIN

    -- get list of apply processes
    v_apply_name_list := get_apply_list(p_staging_owner);

    v_plsql := 'select sum(message_count) ' ||
                 'from dba_apply_error ' ||
                'where apply_name = :apply_name';

    -- count apply process errors
    FOR i IN 1..v_apply_name_list.count
    LOOP
        execute immediate v_plsql
        into v_err_count
        using v_apply_name_list(i);
        IF v_err_count > 0 THEN
            v_err_total := v_err_total + v_err_count;
            mis_gen_pkg.log_strm_message (p_staging_owner, 'apply_error_count',
                              'Apply process ' || v_apply_name_list(i) || ' has ' || v_err_count || ' queued errors.');

        END IF;
    END LOOP;

    return v_err_total;

  EXCEPTION

    WHEN OTHERS THEN
        mis_gen_pkg.log_strm_error (p_staging_owner, 'apply_error_count',
                        p_err_code => SQLCODE, p_text => SQLERRM);
        RAISE;

  END;

  FUNCTION apply_hi_scn(
    p_staging_owner 	IN     varchar2 DEFAULT NULL
  ) RETURN number
  IS
  -- local function apply_hi_scn returns the high watermark SCN
  -- for apply processes associated with a particular staging table owner (if supplied)
  -- n.b. if this is not available, the low watermark is returned instead
  -- n.b.2 if this is not available either information is obtained from the capture process

    v_plsql			varchar2(2000); 
    v_apply_name_list 		apply_list;
    v_capture_name_list 	capture_list;
    v_max_scn 			number;
    v_hi_scn 			number := 0;

  BEGIN

    -- get list of apply processes
    v_apply_name_list := get_apply_list(p_staging_owner);

    v_plsql := 'select nvl(da.max_applied_message_number, dap.applied_message_number) ' ||
                 'from dba_apply_progress dap, dba_apply da ' ||
                'where da.apply_name = :apply_name ' ||
                  'and da.apply_name = dap.apply_name';

    -- get apply SCN
    FOR i IN 1..v_apply_name_list.count
    LOOP
        execute immediate v_plsql
        into v_max_scn
        using v_apply_name_list(i);
        IF v_max_scn IS NOT NULL THEN
            v_hi_scn := greatest(v_hi_scn,v_max_scn);
        END IF;
    END LOOP;

    IF v_hi_scn = 0 THEN
    -- get information from capture
        v_capture_name_list := get_capture_list(p_staging_owner);

        v_plsql := 'select nvl(dc.applied_scn, dc.start_scn) ' ||
                     'from dba_capture dc ' ||
                    'where dc.capture_name = :capture_name';

        -- get applied SCN
        FOR i IN 1..v_capture_name_list.count
        LOOP
            execute immediate v_plsql
            into v_max_scn
            using v_capture_name_list(i);
            IF v_max_scn IS NOT NULL THEN
                v_hi_scn := greatest(v_hi_scn,v_max_scn);
            END IF;
        END LOOP;
    END IF;

    return v_hi_scn;

  EXCEPTION
    WHEN OTHERS THEN
        mis_gen_pkg.log_strm_error (p_staging_owner, 'apply_hi_scn',
                        p_err_code => SQLCODE, p_text => SQLERRM);
        RAISE;
  END;





  PROCEDURE convert_lcr_to_insert (
    p_row_lcr 	IN OUT sys.lcr$_row_record
  ) IS
  -- packaged procedure convert_lcr_to_insert
  -- will convert row LCR record to INSERT
    v_row_lcr_list		sys.lcr$_row_list := NULL;
    v_val_anydata		sys.anydata;
  BEGIN
    -- reset row values to new values only (ensuring all old values are copied over first)
    v_row_lcr_list := p_row_lcr.get_values('old', 'N');
    FOR i IN 1..v_row_lcr_list.count
    LOOP
        v_val_anydata := p_row_lcr.get_value('new', v_row_lcr_list(i).column_name, 'Y');
        BEGIN
            -- add old column value as new
            p_row_lcr.add_column('new', v_row_lcr_list(i).column_name, v_val_anydata);
        EXCEPTION
            WHEN mis_gen_pkg.duplicate_column_name THEN -- ignore error if column value already present
                null;
        END;
        BEGIN
            -- remove old column value (avoids ORA-23605 apply errors)
            p_row_lcr.delete_column(v_row_lcr_list(i).column_name, 'old');
        EXCEPTION
            WHEN mis_gen_pkg.invalid_column THEN -- ignore if column value already deleted
                null;
        END;
    END LOOP;

    -- row does not exist, so insert regardless of command type
    p_row_lcr.set_command_type('INSERT');
  END;

  PROCEDURE parse_anydata_lcr (
    p_in_anydata    IN  sys.anydata,
    p_row_lcr	    OUT sys.lcr$_row_record,
    p_src_db_name   OUT varchar2,
    p_src_obj_owner OUT varchar2,
    p_object_name   OUT varchar2,
    p_command_type  OUT varchar2,
    p_src_time	    OUT DATE,
    p_scn	    OUT number,
    p_tag 	    OUT varchar2
  ) IS
  -- local procedure apply_handler_user
  -- will return important values for ANYDAYA structure containing an LCR.
    v_rtn_val		number;
  BEGIN
    -- get row LCR
    v_rtn_val := p_in_anydata.getObject(p_row_lcr);
    -- get source database name
    p_src_db_name := p_row_lcr.get_source_database_name();
    -- get source object owner
    p_src_obj_owner := p_row_lcr.get_object_owner();
    -- get source object name
    p_object_name := p_row_lcr.get_object_name();
    -- get command type
    p_command_type := p_row_lcr.get_command_type();
    -- get source time for row LCR
    p_src_time := p_row_lcr.get_source_time();
    -- get SCN for row LCR
    p_scn := p_row_lcr.get_scn();
    -- get tag for row LCR
    p_tag := RAWTOHEX(p_row_lcr.get_tag());
  END;


  FUNCTION capture_rule_row_xform_user (
    p_in_anydata    IN sys.anydata,
    p_tgt_owner     IN varchar2,
    p_tgt_tables    IN varchar2,
    p_key_columns   IN varchar2,
    p_proc_flags    IN varchar2
  ) RETURN mis_anydata_array
  IS
  -- packaged function capture_rule_row_xform_user will check row LCRs
  -- destined for tables listed in STRM_TAB_CONTROL prior to queueing.
  -- The function will convert updates that affect target key values
  -- to paired delete and insert records.
  -- Needs to be invoked from a wrapper function to pass in specific
  -- staging table details.

    v_rtn_val			number;
    v_row_lcr0			sys.lcr$_row_record;
    v_row_lcr			sys.lcr$_row_record;
    v_row_lcr2			sys.lcr$_row_record;
    v_out_anydata_array mis_anydata_array;

    v_command_type		varchar2(30) := '';
    v_object_name		varchar2(30);
    v_source_db_name		varchar2(128);
    v_source_object_owner	varchar2(30);
    v_scn			number;
    v_tag 			varchar2(20);
    v_source_time		DATE;
    v_target_object_owner	varchar2(30) := mis_gen_pkg.strip_input(p_tgt_owner,30);
    v_target_object_names	varchar2(400) := mis_gen_pkg.strip_input(p_tgt_tables,400);
    v_tgt_table_list		object_list;
    v_target_object_name	varchar2(30);
    v_plsql			varchar2(4000); 

    v_proc_flags_str		varchar2(400) := mis_gen_pkg.strip_input(p_proc_flags,400);
    v_proc_flags_list		object_list;
    v_proc_flags		varchar2(30);

    v_key_column_str		varchar2(400) := mis_gen_pkg.strip_input(p_key_columns,400);
    v_key_column_list		object_list;
    v_old_key_str		varchar2(2000) := null;
    v_new_key_str		varchar2(2000) := null;
    v_column_name		all_tab_columns.column_name%type;
    v_key_change 		BOOLEAN := FALSE;
    v_command_ok 		BOOLEAN := FALSE;

  BEGIN

    -- create empty return array
    v_out_anydata_array := mis_anydata_array();

    IF p_in_anydata.getTypeName() = 'SYS.LCR$_ROW_RECORD' THEN

        -- get LCR details
        parse_anydata_lcr
           (p_in_anydata, v_row_lcr0, v_source_db_name, v_source_object_owner,
            v_object_name, v_command_type, v_source_time, v_scn, v_tag);

        -- debug message
        mis_gen_pkg.log_strm_debug (v_target_object_owner, 'capture_rule_row_xform_user.1',
                        'Processing ' || v_command_type || ' row LCR for ' || v_source_object_owner || '.' ||
                        v_object_name || '@' || v_source_db_name || '.');

        -- reset object owner to what is stored in the control table
        v_row_lcr0.set_object_owner(v_target_object_owner);

        -- process target table(s)
        v_tgt_table_list := comma_to_object_list(v_target_object_names);
        v_proc_flags_list := comma_to_object_list(v_proc_flags_str);

        FOR i IN 1..v_tgt_table_list.count
        LOOP
            v_row_lcr := v_row_lcr0;
            v_target_object_name := v_tgt_table_list(i);

            -- debug message
            mis_gen_pkg.log_strm_debug (v_target_object_owner, 'capture_rule_row_xform_user.2',
                            'Processing ' || v_command_type || ' row LCR for target table ' ||
                            v_target_object_name || '.');

            -- rename object X to STG_X
            v_row_lcr.set_object_name(v_target_object_name);

            v_proc_flags := nvl(v_proc_flags_list(i),'NONE');

            -- process INSERTs, UPDATES or DELETES, or
            -- if processing flag is set for table include LOB WRITEs and LOB TRIMs
            CASE v_command_type
            WHEN 'INSERT' THEN
                -- convert long data to lob data (just in case)
                v_row_lcr.CONVERT_LONG_TO_LOB_CHUNK();
                IF (instr(v_proc_flags, 'REF') = 0) THEN
                    -- add dummy batch number column
                    v_row_lcr.add_column('new', 'MIS_LOAD_ID', sys.anydata.convertNumber(-1));
                END IF;
                v_command_ok := TRUE;
            WHEN 'UPDATE' THEN
                -- convert long data to lob data (just in case)
                v_row_lcr.CONVERT_LONG_TO_LOB_CHUNK();
                IF (instr(v_proc_flags, 'REF') = 0) THEN
                    -- add dummy batch number column
                    v_row_lcr.add_column('old', 'MIS_LOAD_ID', sys.anydata.convertNumber(-1));
                END IF;
                v_command_ok := TRUE;

                -- debug message
                mis_gen_pkg.log_strm_debug (v_target_object_owner, 'capture_rule_row_xform_user.4',
                                'Checking UPDATE row LCR for ' || v_source_object_owner || '.' ||
                                v_object_name || '@' || v_source_db_name || '.', 2);
                -- get primary key columns
                v_key_column_list := comma_to_object_list(v_key_column_str);

                -- check for key changes
                FOR i IN 1..v_key_column_list.count
                LOOP
                    IF v_key_column_list(i) IS NOT NULL THEN
                        v_new_key_str := convert_anydata_to_varchar2(v_row_lcr.get_value('new',
                                                                     v_key_column_list(i), 'Y'));
                        v_old_key_str := convert_anydata_to_varchar2(v_row_lcr.get_value('old',
                                                                     v_key_column_list(i)));
                        IF v_old_key_str IS NOT NULL AND (v_old_key_str <> v_new_key_str) THEN
                            v_key_change := TRUE;
                            v_column_name := v_key_column_list(i);
                            EXIT; -- do not bother testing other values if any key changed
                        END IF;
                    END IF;
                END LOOP;
            WHEN 'DELETE' THEN
                IF (instr(v_proc_flags, 'REF') = 0) THEN
                    -- add dummy batch number column
                    v_row_lcr.add_column('old', 'MIS_LOAD_ID', sys.anydata.convertNumber(-1));
                END IF;
                v_command_ok := TRUE;
            WHEN 'LONG WRITE' THEN
                IF (instr(v_proc_flags, 'LONG') > 0) THEN
                    -- convert long data to lob data and reset command type
                    v_row_lcr.CONVERT_LONG_TO_LOB_CHUNK();
                    v_command_type := v_row_lcr.get_command_type();
                    IF (instr(v_proc_flags, 'REF') = 0) THEN
                        -- add dummy batch number column
                        v_row_lcr.add_column('new', 'MIS_LOAD_ID', sys.anydata.convertNumber(-1));
                    END IF;
                    v_command_ok := TRUE;
                END IF;
            ELSE
                IF (((instr(v_proc_flags, 'LOB') > 0) OR (instr(v_proc_flags, 'LONG') > 0)) AND
                    v_command_type IN ('LOB WRITE','LOB TRIM','LOB ERASE')) THEN
                    -- add dummy batch number column
                    IF (instr(v_proc_flags, 'REF') = 0) THEN
                        v_row_lcr.add_column('new', 'MIS_LOAD_ID', sys.anydata.convertNumber(-1));
                    END IF;
                    v_command_ok := TRUE;
                END IF;
            END CASE;

            IF v_key_change THEN
        
                -- split update that modifies key values into a delete and an insert
                -- N.B. updates to keys and out-of-line LOBs at the same time result
                -- in apply errors (whether or not the record is split).

                -- log message
                mis_gen_pkg.log_strm_message(v_target_object_owner, 'capture_rule_row_xform_user.6',
                             'Update to key values detected for ' ||
                             v_source_object_owner || '.' ||v_object_name || '@' || v_source_db_name ||
                             ' (column_name=' || v_column_name || ' old:' || v_old_key_str ||
                             ' new:' || v_new_key_str || ' scn=' || v_row_lcr.get_scn() ||
                             '). Splitting row LCR.');

                -- copy LCR record
                v_row_lcr2 := v_row_lcr;

                -- convert original LCR to delete
                v_row_lcr.set_values('new', NULL);
                v_row_lcr.set_command_type('DELETE');

                -- tag delete row LCR for apply process
                v_row_lcr.set_tag(HEXTORAW(g_tag2));

                -- tag insert row LCR for apply process
                v_row_lcr2.set_tag(HEXTORAW(g_tag));

                -- convert copy LCR to insert
                convert_lcr_to_insert(v_row_lcr2);

                -- insert LCRs into output ANYDATA array
                v_out_anydata_array.extend(2);
                v_out_anydata_array(v_out_anydata_array.count-1) := sys.anydata.convertObject(v_row_lcr);
                v_out_anydata_array(v_out_anydata_array.count) := sys.anydata.convertObject(v_row_lcr2);

            ELSIF v_command_ok THEN

                -- debug message
                mis_gen_pkg.log_strm_debug (v_target_object_owner, 'capture_rule_row_xform_user.7',
                            'Capturing ' || v_command_type || ' row LCR for ' ||
                            v_source_object_owner || '.' ||
                            v_object_name || '@' || v_source_db_name || ', scn=' || v_row_lcr.get_scn() || '.');

                -- tag row LCR for apply process
                v_row_lcr.set_tag(HEXTORAW(g_tag));

                -- insert LCR into output ANYDATA array
                v_out_anydata_array.extend();
                v_out_anydata_array(v_out_anydata_array.count) := sys.anydata.convertObject(v_row_lcr);

            ELSE

                -- return empty array for row LCRs of wrong command type; debug message
                mis_gen_pkg.log_strm_debug (v_target_object_owner, 'capture_rule_row_xform_user.8',
                            'Rejected ' || v_command_type || ' row LCR for ' || v_source_object_owner || '.' ||
                            v_object_name || '@' || v_source_db_name || '.');

            END IF;
        END LOOP;

    ELSE

        -- return empty array for non-row LCRs; log message
        mis_gen_pkg.log_strm_message(v_target_object_owner, 'capture_rule_row_xform_user.9',
                         'Rejected non-row LCR.');

    END IF;

    return v_out_anydata_array;

    EXCEPTION

        WHEN OTHERS THEN -- *** ABORT CAPTURE PROCESS ***
            mis_gen_pkg.log_strm_error (v_target_object_owner, 'capture_rule_row_xform_user',
                p_src_db => v_source_db_name, p_src_owner => v_source_object_owner,
                p_src_table => v_object_name, p_tgt_table => v_target_object_name,
                p_err_code => SQLCODE, p_text => SQLERRM);
            RAISE;

  END;


  PROCEDURE apply_handler_user (
    p_in_anydata    IN sys.anydata,
    p_batch_number  IN varchar2,
    p_tgt_owner     IN varchar2,
    p_tgt_table     IN varchar2,
    p_key_columns   IN varchar2,
    p_keep_dups     IN char,
    p_proc_flags    IN varchar2,
    p_del_columns   IN varchar2
  ) IS

  -- packaged procedure apply_handler_user
  -- Will convert queued row LCRs for Target tables and apply them.
  -- It is assumed that the capture process will only capture row LCRs for OMS_OWNER.X tables.
  -- Needs to be invoked from a wrapper function to pass in specific user name for
  -- staging table owner, staging table name, key and deletion column names and processing flags.

    v_rtn_val			number;
    v_row_lcr			sys.lcr$_row_record;
    v_lcr_anydata_array mis_anydata_array;

    v_command_type		varchar2(30);
    v_object_name		varchar2(30) := null;
    v_scn			number := null;
    v_tag 			varchar2(20) := null;
    v_source_db_name		varchar2(128) := null;
    v_source_object_owner	varchar2(30) := null;
    v_target_object_owner	varchar2(30) := mis_gen_pkg.strip_input(p_tgt_owner,30);
    v_target_object_name	varchar2(30) := mis_gen_pkg.strip_input(p_tgt_table,30);
    v_row_lcr_list		sys.lcr$_row_list := NULL;
    v_plsql			varchar2(4000); 

    v_batch_number		NUMBER(38,0) := nvl(p_batch_number,-1);
    v_source_time		DATE := null;
    v_row_count			number := -1;
    v_max_scn			number := null;
    v_command_flag		char := ' ';
    v_keep_dups			char := p_keep_dups;
    v_proc_flags		varchar2(30) := nvl(mis_gen_pkg.strip_input(p_proc_flags,30),'NONE');

    v_missing_column_list	object_list;
    v_key_column_list		object_list;
    v_val_anydata		sys.anydata;
    v_where_clause		varchar2(4000) := '';
    
    v_execute 			BOOLEAN := TRUE;

    FUNCTION get_where_clause (
        p_row_lcr		IN     sys.lcr$_row_record,
        p_key_column_str  	IN     varchar2,
        p_key_column_list 	OUT    object_list,
        p_tgt_owner  		IN     varchar2,
        p_tgt_object  		IN     varchar2,
        p_proc_flags  		IN     varchar2,
        p_batch_number  	IN     number,
        p_default 		IN     varchar2
    ) RETURN varchar2 IS
    
        l_plsql			varchar2(4000); 
        l_key_str		varchar2(2000) := null;
        l_where_clause		varchar2(4000) := '';
    
    BEGIN
        -- get primary key columns
        p_key_column_list := comma_to_object_list(p_key_column_str);
    
        IF p_key_column_list.count > 0 THEN
            -- primary key info defined, check for record existence
            IF (instr(p_proc_flags, 'REF') = 0) THEN
                l_where_clause := 'where MIS_LOAD_ID=' || p_batch_number;
            ELSE
                l_where_clause := 'where 1=1';
            END IF;

            FOR i IN 1..p_key_column_list.count
            LOOP
                IF p_key_column_list(i) IS NOT NULL THEN
                    l_key_str := convert_anydata_to_varchar2(p_row_lcr.get_value('new',
                                                         p_key_column_list(i), p_default));
                    IF l_key_str IS NOT NULL THEN
                        -- escape embedded single quotes
                        l_key_str := replace(l_key_str, '''', '''''');
                        -- append key to where clause
                        l_where_clause := l_where_clause || ' and ' || p_key_column_list(i) ||
                                          '=''' || l_key_str || '''';
                    END IF;
                END IF;
            END LOOP;
        END IF;
        
        return l_where_clause;

    END get_where_clause;

  BEGIN

    IF p_in_anydata.getTypeName() = 'SYS.LCR$_ROW_RECORD' THEN

        -- Call original Streams Capture DML Handler.
        -- The function will return a delete and insert row LCR to replace an update row LCR if any of the PK cols are being updated.
/*        v_lcr_anydata_array := capture_rule_row_xform_user (
            p_in_anydata,
            p_tgt_owner,
            p_tgt_table,
            p_key_columns,
            p_proc_flags
        );

        -- get row LCR
        v_rtn_val := p_in_anydata.getObject(p_row_lcr);
*/

        -----------------------------------------------
        -- Start of original Streams DML Apply Handler.
        -----------------------------------------------

        -- get LCR details
        parse_anydata_lcr
           (p_in_anydata, v_row_lcr, v_source_db_name, v_source_object_owner,
            v_object_name, v_command_type, v_source_time, v_scn, v_tag);

        -- debug message
        mis_gen_pkg.log_strm_debug (v_target_object_owner, 'apply_handler_user.1',
                        'Processing ' || v_command_type || ' row LCR for ' ||
                        v_source_object_owner || '.' || v_object_name || '@' ||
                        v_source_db_name || '.', 2);


        IF v_command_type IN ('LOB WRITE','LOB TRIM','LOB ERASE','LOB_UPDATE') THEN

            -- *** pass through LCR with no further changes if LOB processing enabled ***
            IF (instr(v_proc_flags, 'LOB') > 0) OR (instr(v_proc_flags, 'LONG') > 0) THEN

                -- debug message
                mis_gen_pkg.log_strm_debug (v_target_object_owner, 'apply_handler_user.2',
                                'Processing ' || v_command_type || ' row LCR for ' || v_target_object_name ||
                                ' (batch number ' || v_batch_number || ').', 1);

                IF (instr(v_proc_flags, 'REF') = 0) THEN
                    -- add new batch number column
                    v_row_lcr.set_value('new', 'MIS_LOAD_ID', sys.anydata.convertNumber(v_batch_number));
                END IF;

            ELSE
                v_execute := false;
            END IF;

            -- determine where clause for logging
            v_where_clause := get_where_clause
                                 (v_row_lcr, p_key_columns, v_key_column_list, v_target_object_owner,
                                  v_target_object_name, v_proc_flags, v_batch_number, 'N');

        ELSE

            -- debug message
            mis_gen_pkg.log_strm_debug (v_target_object_owner, 'apply_handler_user.3',
                            'Processing ' || v_command_type || ' row LCR for ' || v_target_object_name ||
                            ' (batch number ' || v_batch_number || ').', 1);

            -- remove columns that do not exist in target table
            v_missing_column_list := comma_to_object_list(p_del_columns);

            FOR i IN 1..v_missing_column_list.count
            LOOP
                BEGIN
                    v_row_lcr.delete_column(v_missing_column_list(i));
                EXCEPTION
                    WHEN invalid_column THEN null; -- ignore if column already deleted
                    WHEN invalid_null_value THEN null; -- ignore if no missing column name
                END;
            END LOOP;

            -- treat all rows as potential updates (enables get new values defaulting)
            v_row_lcr.set_command_type('UPDATE');
            -- determine where clause for row check/upsert handling
            v_where_clause := get_where_clause
                                 (v_row_lcr, p_key_columns, v_key_column_list,
                                  v_target_object_owner, v_target_object_name,
                                  v_proc_flags, v_batch_number, 'Y');

            -- These are now done in the Replicat parameter file
            -- add source time
            --v_row_lcr.add_column('new', 'MIS_SOURCE_TIME', sys.anydata.convertDate(v_source_time));
            -- add command flag column (I/U/D/L)
            --v_command_flag := substr(v_command_type,1,1);
            --v_row_lcr.add_column('new', 'MIS_COMMAND_FLAG', sys.anydata.convertChar(v_command_flag));
            -- add scn column
            --v_row_lcr.add_column('new', 'MIS_SCN', sys.anydata.convertNumber(v_scn));

            IF v_command_type = 'INSERT' THEN
                IF (instr(v_proc_flags, 'REF') = 0) THEN
                  -- set new batch number column
                  v_row_lcr.set_value('new', 'MIS_LOAD_ID', sys.anydata.convertNumber(v_batch_number));
                END IF;
                -- reset to insert
                v_row_lcr.set_command_type('INSERT');
            ELSE
                IF (instr(v_proc_flags, 'REF') = 0) THEN
                  -- set old batch number column
                  v_row_lcr.set_value('old', 'MIS_LOAD_ID', sys.anydata.convertNumber(v_batch_number));
                END IF;

                IF (v_tag = g_tag2) THEN
                    -- debug message
                    mis_gen_pkg.log_strm_debug (v_target_object_owner, 'apply_handler_user.5',
                        'Processing target row LCR for ' || v_target_object_name || ' (' ||
                        v_where_clause || ').');

                    -- determine whether row already exists for target batch
                    v_plsql := 'select count(MIS_SCN), max(MIS_SCN) from ' ||
                                      v_target_object_owner || '.' || v_target_object_name || ' ' ||
                                      v_where_clause;  
                    execute immediate v_plsql into v_row_count, v_max_scn;

                    -- check execution condition for records flagged as old key values
                    IF (v_scn = v_max_scn) THEN
                        v_execute := FALSE;
                    END IF;
                END IF;

                -- row presumed not to exist, so insert regardless of command type
                -- reset row values to new values only (ensuring all old values are copied over first)
                convert_lcr_to_insert(v_row_lcr);

            END IF;

        END IF;

    	  IF v_execute THEN
            -- debug message
            mis_gen_pkg.log_strm_debug (v_target_object_owner, 'apply_handler_user.7',
                            'Executing ' || v_row_lcr.get_command_type() || ' row LCR for ' ||
                            v_target_object_name || ' (' || v_where_clause || ').');

            BEGIN
                v_row_lcr.execute(conflict_resolution => FALSE);
            EXCEPTION
                WHEN DUP_VAL_ON_INDEX OR NO_DATA_FOUND THEN
                    IF (v_row_count = 0) OR (v_keep_dups = 'Y') THEN
                        -- should not be INSERT/UPDATE issues in these cases
                        RAISE;
                    ELSE
                        -- reset to update
                        v_row_lcr.set_command_type('UPDATE');
                        IF (instr(v_proc_flags, 'REF') = 0) THEN
                        -- set old key values
                            v_row_lcr.add_column('old', 'MIS_LOAD_ID', sys.anydata.convertNumber(v_batch_number));
                        END IF;

                        FOR i IN 1..v_key_column_list.count
                        LOOP
                            IF v_key_column_list(i) IS NOT NULL THEN
                                v_val_anydata := v_row_lcr.get_value('new', v_key_column_list(i), 'Y');
                                -- make sure the old key value is set
                                v_row_lcr.add_column('old', v_key_column_list(i), v_val_anydata);
                            END IF;
                        END LOOP;
                        
                        -- debug message
                        mis_gen_pkg.log_strm_debug (v_target_object_owner, 'apply_handler_user.7a',
                            'Re-executing ' || v_row_lcr.get_command_type() || ' row LCR for ' ||
                            v_target_object_name || '.');

                        BEGIN
                        -- retry as update
                            v_row_lcr.execute(conflict_resolution => FALSE);
                        END;
                    END IF;
            END;
        ELSE
            -- debug message
            mis_gen_pkg.log_strm_debug (v_target_object_owner, 'apply_handler_user.8',
                            'Not executing ' || v_row_lcr.get_command_type() || ' row LCR for ' ||
                            v_target_object_name || ' (' || v_where_clause || ').');
        END IF;

    END IF;

  EXCEPTION

    WHEN invalid_lob_locator THEN
        -- log error then ignore
        mis_gen_pkg.log_strm_error (v_target_object_owner, 'apply_handler_user.9',
            p_src_db => v_source_db_name, p_src_owner => v_source_object_owner,
            p_src_table => v_object_name, p_tgt_table => v_target_object_name,
            p_batch_id => v_batch_number, p_err_code => SQLCODE,
            p_text => 'Invalid LOB locator for ' ||
                      v_row_lcr.get_command_type() || ' on ' ||
                      v_target_object_name || ' ('||v_where_clause||')');
        -- update message on active batch (but do not set error flag)
        update_batch_record_force(v_batch_number, null, null, 'Invalid LOB locator for ' ||
                                  v_target_object_name);

    WHEN OTHERS THEN -- *** ABORT APPLY PROCESS ***
        mis_gen_pkg.log_strm_error (v_target_object_owner, 'apply_handler_user',
            p_src_db => v_source_db_name, p_src_owner => v_source_object_owner,
            p_src_table => v_object_name, p_tgt_table => v_target_object_name,
            p_batch_id => v_batch_number,
            p_err_code => SQLCODE, p_text => SQLERRM);
        -- update error flag and message on active batch
        update_batch_record_force(v_batch_number, 'Y', null, 'Apply transform error ('||SQLCODE||')');

        RAISE;

  END;


  PROCEDURE set_apply_handlers (
    p_tgt_owner 	IN     VARCHAR2
  ) IS
  -- packaged procedure set_apply_handlers
  -- will set DML apply handlers for source tables in p_tgt_owner.STRM_TAB_CONTROL

    l_plsql 		varchar2(4000); 
    l_tgt_owner		varchar2(32) := mis_gen_pkg.strip_input(p_tgt_owner,32);
    l_apply_handler	varchar2(32);
    l_batch_number	NUMBER(38,0) := -1;

    l_src_owner_list		owner_list;
    l_src_table_list		object_list;
    l_tgt_table_list		object_list;
    l_keep_dups_list		keep_dups_list;
    l_proc_flag_list		object_list;
    l_tab_seq_list              tab_seq_list;
    l_key_columns_list		key_col_list ;
    l_del_columns_list		object_list ;

    procedure set_apply_handler (
        p_tgt_owner 	IN     VARCHAR2,
        p_src_owner 	IN     VARCHAR2,
        p_table 	IN     VARCHAR2,
 	p_command_type 	IN     VARCHAR2,
        p_apply_handler IN     VARCHAR2
    ) is
        l_apply_name 	VARCHAR2(32) := get_apply_name(p_src_owner);
        l_plsql 	varchar2(2000); 
    begin
        l_plsql := 
            'begin dbms_apply_adm.set_dml_handler(
		object_name => ''' || p_tgt_owner || '.' || p_table || ''',
		object_type => ''TABLE'',
		operation_name => ''' || p_command_type || ''',
		error_handler => false,
		user_procedure => ''' || p_apply_handler || ''',
		apply_database_link => null,
		apply_name => ''' || l_apply_name || ''',
		assemble_lobs => false); end;'; 
        execute immediate l_plsql;
    end;

  BEGIN
    -- get active batch number
    l_batch_number := get_batch_number(l_tgt_owner);

    -- retrieve details of all target tables
    l_plsql := 'select src_owner, src_table, tgt_table, keep_dups, proc_flags, tab_seq, key_columns ' ||
                 'from ' || l_tgt_owner || '.STRM_TAB_CONTROL';

    execute immediate l_plsql
    bulk collect into l_src_owner_list, l_src_table_list, l_tgt_table_list,
                      l_keep_dups_list, l_proc_flag_list, l_tab_seq_list, l_key_columns_list;

    -- define handlers for each table
    FOR i in 1..l_src_owner_list.count
    LOOP
        -- get handler name
        l_apply_handler	:= get_dml_proc_name(l_tgt_owner, l_tab_seq_list(i), l_key_columns_list(i));

        -- determine columns to be deleted from LCRs for table
        l_plsql := 'select src_column ' ||
                     'from ' || l_tgt_owner || '.' || 'STRM_COL_DELETIONS ' ||
                    'where tgt_table = :tgt_table';  
        execute immediate l_plsql bulk collect into l_del_columns_list
        using l_tgt_table_list(i);

        -- create DML Apply procedure for table
        l_plsql := 'CREATE OR REPLACE PROCEDURE ' || l_apply_handler || '(p_in_anydata IN sys.anydata) AS ' ||
            'BEGIN ' ||
                'mis.mis_DML_PKG.apply_handler_user' ||
                '(p_in_anydata,'||l_batch_number||','''||l_tgt_owner||''','''||
                  l_tgt_table_list(i)||''','''||l_key_columns_list(i)||''','''||
                  l_keep_dups_list(i)||''','''||l_proc_flag_list(i)||''','''||
                  object_list_to_comma(l_del_columns_list)||'''); ' ||
            'END;';
        dbms_utility.exec_ddl_statement(l_plsql);

        -- set handlers
        set_apply_handler(l_tgt_owner, l_src_owner_list(i), l_tgt_table_list(i), 'INSERT', l_apply_handler);
        set_apply_handler(l_tgt_owner, l_src_owner_list(i), l_tgt_table_list(i), 'UPDATE', l_apply_handler);
        set_apply_handler(l_tgt_owner, l_src_owner_list(i), l_tgt_table_list(i), 'DELETE', l_apply_handler);
        IF (instr(l_proc_flag_list(i), 'LOB') > 0) OR (instr(l_proc_flag_list(i), 'LONG') > 0) THEN
            set_apply_handler
               (l_tgt_owner, l_src_owner_list(i), l_tgt_table_list(i), 'LOB_UPDATE', l_apply_handler);
        END IF;
    END LOOP;

    mis_gen_pkg.log_strm_debug (l_tgt_owner, 'set_apply_handlers',
                    'DML apply handlers reset for ' || l_src_owner_list.count || ' tables.');

  EXCEPTION

    WHEN OTHERS THEN
        mis_gen_pkg.log_strm_error (l_tgt_owner, 'set_apply_handlers',
                        p_err_code => SQLCODE, p_text => SQLERRM);
        RAISE;

  END;


  PROCEDURE clear_apply_handlers (
    p_tgt_owner 	IN     VARCHAR2
  ) IS
  -- packaged procedure clear_apply_handlers
  -- will remove DML handlers for apply processes related to p_tgt_owner

    l_plsql 		varchar2(2000); 
    l_plsql2 		varchar2(2000); 
    l_tgt_owner		varchar2(32) := mis_gen_pkg.strip_input(p_tgt_owner,32);

    l_src_owner_list		owner_list;
    l_src_table_list		object_list;
    l_operations_list		operations_list;
    l_procedure_list		procedure_list;
    l_apply_name_list 		apply_list;

    procedure clear_apply_handler (
        p_apply_name 	IN     VARCHAR2,
 	p_src_owner 	IN     VARCHAR2,
        p_src_table 	IN     VARCHAR2,
 	p_command_type 	IN     VARCHAR2
    ) is
        l_plsql 	varchar2(2000);
    begin
        l_plsql := 
            'begin dbms_apply_adm.set_dml_handler(
		object_name => ''' || p_src_owner || '.' || p_src_table || ''',
		object_type => ''TABLE'',
		operation_name => ''' || p_command_type || ''',
		error_handler => false,
		user_procedure => null,
		apply_database_link => null,
		apply_name => ''' || p_apply_name || ''',
		assemble_lobs => false); end;'; 
        execute immediate l_plsql;
    end;

  BEGIN
    -- get list of apply processes
    l_apply_name_list := get_apply_list(l_tgt_owner);

    -- retrieve details of all target tables
    l_plsql := 'select OBJECT_OWNER, OBJECT_NAME, OPERATION_NAME, ' ||
                      'REPLACE(USER_PROCEDURE,''"'','''') USER_PROCEDURE ' ||
                 'from DBA_APPLY_DML_HANDLERS ' ||
                'where APPLY_NAME = :apply_name';

    -- clear handlers for each apply process
    FOR i in 1..l_apply_name_list.count
    LOOP

        execute immediate l_plsql
        bulk collect into l_src_owner_list, l_src_table_list, l_operations_list, l_procedure_list
        using l_apply_name_list(i);

        -- clear handlers for each table
        FOR j in 1..l_src_owner_list.count
        LOOP
            -- clear handler
            clear_apply_handler
                (l_apply_name_list(i), l_src_owner_list(j), l_src_table_list(j), l_operations_list(j));
            -- drop DML Apply procedure for table
            BEGIN
                l_plsql2 := 'DROP PROCEDURE ' || l_procedure_list(j);
                dbms_utility.exec_ddl_statement(l_plsql2);
            EXCEPTION WHEN OTHERS THEN null;
            END;
        END LOOP;

        mis_gen_pkg.log_strm_debug (l_tgt_owner, 'clear_apply_handlers',
                        'DML apply handlers cleared for ' || l_src_owner_list.count || ' tables.');
    END LOOP;

  EXCEPTION

    WHEN OTHERS THEN
        mis_gen_pkg.log_strm_error (l_tgt_owner, 'set_apply_handlers',
                        p_err_code => SQLCODE, p_text => SQLERRM);
        RAISE;

  END;


END MIS_DML_PKG;
/

show errors
