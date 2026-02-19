CREATE OR REPLACE PACKAGE MIS_BATCH_PKG AUTHID DEFINER AS
/*
 *  NOMIS MIS Goldengate code.
 *  
 *  Description:  	This script creates procedures to support
 *                      Oracle Goldengate batch id processes for Prison-NOMIS release 1.0e.
 *                  Based on MIS_STRM_PKG1
 *  
 *                      This script should be executed by the MIS user.
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

    -- Packaged function get_batch_number returns the active batch number for
    -- the staging process, derived from the ETL_LOAD_LOG table
    FUNCTION get_batch_number(
        p_staging_owner 	IN varchar2,
        p_ignore_datetime 	IN BOOLEAN DEFAULT FALSE
    ) RETURN number;

    -- Packaged function get_scn_timestamp returns the timestamp
    -- for a SCN value derived from the source database for a queue
    FUNCTION get_scn_timestamp(
        p_scn 		IN     number)
    RETURN TIMESTAMP;

    -- Packaged procedure update_batch_record_force updates the batch control table.
    -- Called from DML Handler.
    PROCEDURE update_batch_record_force(
        p_batch_number 	IN     number,
        p_error_flag 	IN     varchar2,
        p_staged_end_date 	IN     date DEFAULT null,
        p_message 		IN     varchar2 DEFAULT null
    );

    -- Packaged procedure renumber_old_batch_rows updates the batch number
    -- for rows in all staging table owned by the specified user.
    -- Use with Caution!
    PROCEDURE renumber_old_batch_rows(
        p_tgt_owner 	    IN     varchar2,
        p_new_batch_number  IN     number,
        p_old_batch_number  IN     number DEFAULT -1);

    -- Packaged procedure create_new_batch
    -- stops running apply processes,
    -- creates a new batch entry for the supplied staging table owner,
    -- marks previous batch as complete, tidies any orphan rows,
    -- restarts apply processes. 
    PROCEDURE create_new_batch(
        p_staging_owner 	IN  varchar2,
        p_restart 		IN  BOOLEAN DEFAULT TRUE,
        p_more_points 		OUT BOOLEAN);

    -- Packaged procedure reload_tables
    -- will insert/overwrite entries for latest batch in p_tgt_owner.p_tgt_table
    -- with all data from associated source table.
    PROCEDURE reload_tables (
        p_tgt_owner 	IN     VARCHAR2,
        p_tgt_table 	IN     VARCHAR2 DEFAULT null);

    -- Packaged procedure unload_tables
    -- will delete entries for (latest) batch in p_tgt_owner.p_tgt_table
    -- where mis_scn >= p_stop_scn.
    PROCEDURE unload_tables (
        p_tgt_owner 	IN     VARCHAR2,
        p_stop_scn 	IN     NUMBER DEFAULT 0,
        p_batch_number 	IN     NUMBER DEFAULT null,
        p_tgt_table 	IN     VARCHAR2 DEFAULT null);

END MIS_BATCH_PKG;
/

show errors
