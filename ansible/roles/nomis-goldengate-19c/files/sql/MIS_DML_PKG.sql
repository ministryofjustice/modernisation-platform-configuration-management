CREATE OR REPLACE PACKAGE MIS_DML_PKG AUTHID DEFINER AS
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
 *			1.1.2	  11/06/07  R. Taylor	Added procedures for creating and
 *                                                      dropping capture and apply processes.
 *                                                      Added procedures for handling column
 *                                                      type differences between source and target.
 *			1.1.3	  13/06/07  R. Taylor	Added data type check to capture and
 *                                                      apply startup procedures.
 *                                                      Add refresh_apply_keys procedure.
 *			1.1.4	  26/06/07  R. Taylor	Added exception definitions.
 *			1.1.5	  05/07/07  R. Taylor	Added exception definitions.
 *                                                      Add table existence check procedure.
 *			1.1.8	  24/07/07  R. Taylor	Added exception definitions.
 *			1.0e.9	  17/09/07  R. Taylor	Renumbered for switch from 1.1 to 1.0e.
 *                                                      Redesigned to use DML apply handlers to cope with
 *                                                      multiple key updates expected with offender merge.
 *			1.0e.10	  26/09/07  R. Taylor	Additional LCR tag value added.
 *			1.0e.11	  01/10/07  R. Taylor	Added exception definitions.
 *			1.0e.13	  05/05/08  P. Godhania	Add definitions for log_purge procedure.
 *			1.0e.14	  07/05/08  R. Taylor	Added exception definitions.
 *			1.0e.15	  20/05/08  R. Taylor	Modified g_debug setting.
 *			1.0e.16	  27/05/08  R. Taylor	Updated start_capture/start_apply comments.
 *                                                      Added queue exception.
 *			1.0e.17	  10/06/08  R. Taylor	Added timeout exception.
 *			1.0e.18	  12/06/08  R. Taylor	Added sleep before retry periods.
 *			1.0e.19	  15/08/08  R. Taylor	refresh_col_controls/check_col_differences will
 *                                                      now detect not null target columns not in source.
 *			1.0e.20	  15/08/08  R. Taylor	Always convert LONG columns to LOB in capture
 *                                                      transformation to avoid errors from apply process. 
 *			1.0e.21	  01/09/08  R. Taylor	Add extra list types and get_dml_proc_name function.
 *			1.0e.22	  10/09/08  R. Taylor	Add get_capture_nrs_name function.
 *                                                      Increase sleep values for retry of stop_apply/capture. 
 *                                                      Add reload_tables procedure.
 *			1.0e.23	  22/09/08  R. Taylor	Amend start_apply procedure parameters.
 *                                                      Add clear_apply_handlers procedure.
 *                      1.0e.24	  23/09/08  R. Taylor   Added invalid parameter value and
 *                                                      invalid data type exceptions.
 *			1.0e.25	  24/09/08  R. Taylor	Increase internal buffer length in reload_tables.
 *			1.0e.26	  17/10/08  R. Taylor	Expose log_strm_error procedure (previously local).
 *			1.0e.27	  19/12/08  R. Taylor	Added stop point handling.
 *                      1.0e.28	  15/01/09  R. Taylor   Added control job exception.
 *			1.0e.29	  19/01/09  R. Taylor	Ensure apply running during wait for stop points.
 *			1.0e.30	  22/01/09  R. Taylor	Add function get_scn_timestamp.
 *			1.0e.31	  23/01/09  R. Taylor	Remove get_scn_timestamp function as cannot invoke
 *                                                      scn_to_timestamp across database link parameter.
 *                                                      Call set_stop_points at end of create_new_batch and
 *                                                      return output parameter.
 *			1.0e.32	  26/01/09  R. Taylor	Use capture log date for staged end date in create_new_batch.
 *			1.0e.33	  04/03/09  R. Taylor	Define exception number constants.
 *			1.0e.34	  19/03/09  R. Taylor	Defect 14424 - further modify capture control for stop points.
 *			1.0e.35	  22/03/09  R. Taylor	Add function get_scn_timestamp.
 *                                                      Add unload_tables procedure.
 *			1.0e.36	  06/08/09  R. Taylor	Add procedure set_capture_pos_rules. Use in start_capture.
 *			1.0e.37	  14/08/09  R. Taylor	Define maximum number of expected key columns.
 *			1.0e.38	  12/10/09  R. Taylor	Define retry limit for stop point waiting.
 *			1.0e.39	  14/10/09  R. Taylor	Define constants for statistics refresh control.
 *			1.0e.40	  26/10/09  R. Taylor	Modify sleep/retry limits for process control.
 *			1.0e.41   30/11/09  R. Taylor	Revert apply handler to remove bind variable use.
 *			1.0e.42   14/12/09  R. Taylor	Revert capture transform command type checking.
 *			1.0e.43   19/01/10  R. Taylor	Remove redundant g_max_rows variable.
 *			1.0e.44   13/01/10  R. Taylor	Define row count to which stats recalc will be presumed.
 *			1.0e.45   19/01/10  R. Taylor	Reinstated capture transform command type checking changes.
 *			1.0e.46   21/01/10  R. Taylor	Always try insert first in apply handler.
 *			1.0e.47   21/01/10  R. Taylor	Pass batch number into apply handler.
 *			1.0e.48   08/02/10  R. Taylor	Convert schema name in capture transform.
 *			1.0e.49   15/02/10  R. Taylor	Split positive capture rules out by table.
 *                                                      Add procedure clear_capture_pos_rules.
 *			1.0e.50   25/02/10  R. Taylor	Explicitly set instantiation scn for new tables.
 *			1.0e.51	  01/03/10  R. Taylor	Specify command types in positive capture rules.
 *			1.0e.52	  11/03/10  R. Taylor	Added get_version function.
 *			1.0e.53	  06/08/10  R. Taylor	Modified for Oracle 11gR1.
 *			1.0e.54	  12/08/10  R. Taylor	Updated to allow for normal and reference target tables
 *                                                      from a common source table.
 *                                                      Define value for mis_owner at top of script.
 *			1.0e.55	  02/09/10  R. Taylor	Allow for missing key columns.
 *			1.0e.56	  08/09/10  R. Taylor	Adjust LOB table rule conditions.
 *			1.0e.57	  15/09/10  R. Taylor	Change REF table exception handling.
 *                                                      Added log_apply procedure.
 *			1.0e.58	  16/09/10  R. Taylor	Change mis_scn handling in unload_tables.
 *			1.0e.59	  01/05/13  R. Taylor	Added purge_records procedure (defect 19143).
 *			1.0e.60	  27/01/26  Migration	Migrated PK change detection from Streams Capture to
 *                                                      GoldenGate Replicat apply handler. UPDATEs that modify
 *                                                      PK columns are now split into DELETE+INSERT within
 *                                                      apply_handler_user procedure for GG compatibility.
 */

    -- package level variable declarations
    g_version 	 	VARCHAR2(20) := '1.0e.60';

    -- debug flag: positive value to log debug messages
    g_debug NUMBER := 1;

    -- LCR tags: values used to flag messages for apply process
    g_tag  VARCHAR2(20) := '01';
    g_tag2 VARCHAR2(20) := '02';


    -- Packaged function convert_anydata_to_varchar2
    -- will convert a SYS.ANYDATA record to a VARCHAR2 string
    FUNCTION convert_anydata_to_varchar2 (
        p_any_val 	IN     sys.anydata)
    RETURN varchar2;

    -- packaged function convert_anydata_to_date
    -- will convert a SYS.ANYDATA record to a date value
    FUNCTION convert_anydata_to_date (
        p_any_val in sys.anydata)
    RETURN date;

    -- Packaged function get_xform_func_name returns the capture
    -- transformation name for the supplied target table
    FUNCTION get_xform_func_name(
        p_tgt_owner 		IN     VARCHAR2,
        p_tab_seq	 	IN     NUMBER)
    RETURN varchar2 RESULT_CACHE;

    -- Packaged function get_dml_proc_name returns the dml handler name
    -- for the supplied target table (includes hash of key column names)
    FUNCTION get_dml_proc_name(
        p_tgt_owner 		IN     VARCHAR2,
        p_tab_seq	 	IN     NUMBER,
        p_key_columns	 	IN     VARCHAR2)
    RETURN varchar2 RESULT_CACHE;

    -- Packaged procedure convert_lcr_to_insert
    -- will convert row LCR record to INSERT
    PROCEDURE convert_lcr_to_insert (
        p_row_lcr 	IN OUT sys.lcr$_row_record);

    -- Packaged procedure apply_handler_user
    -- will convert queued row LCRs for Target tables prior to direct apply
    -- It is assumed that the capture process will only capture row LCRs for OMS_OWNER.X tables.
    -- The function will convert updates that affect target key values
    -- to paired delete and insert records.
    -- Needs to be invoked from a wrapper function to pass in specific user name for
    -- staging table owner, staging table name, key and deletion column names and processing flags.
    PROCEDURE apply_handler_user (
        p_in_anydata    IN sys.anydata,
        p_batch_number  IN varchar2,
        p_tgt_owner     IN varchar2,
        p_tgt_table     IN varchar2,
        p_key_columns   IN varchar2,
        p_keep_dups     IN char,
        p_proc_flags    IN varchar2,
        p_del_columns   IN varchar2);


    -- Packaged procedure set_apply_handlers
    -- will set DML apply handlers for source tables in p_tgt_owner.STRM_TAB_CONTROL
    PROCEDURE set_apply_handlers (
        p_tgt_owner 	IN     VARCHAR2);

    -- Packaged procedure clear_apply_handlers
    -- will remove DML handlers for apply processes related to p_tgt_owner
    PROCEDURE clear_apply_handlers (
        p_tgt_owner 	IN     VARCHAR2);

    -- Packaged function get_version
    -- will return a VARCHAR2 string containing a package version number
    FUNCTION get_version RETURN varchar2;

END MIS_DML_PKG;
/

show errors
