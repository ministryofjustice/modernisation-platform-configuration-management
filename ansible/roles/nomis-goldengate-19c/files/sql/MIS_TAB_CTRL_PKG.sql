CREATE OR REPLACE PACKAGE MIS_TAB_CTRL_PKG AUTHID DEFINER AS
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

    -- package level variable declarations
    g_version 	 	VARCHAR2(20) := '1.0e.59';


    -- Packaged function get_version
    -- will return a VARCHAR2 string containing a package version number
    FUNCTION get_version RETURN varchar2;

    -- Packaged procedure add_tab_control
    -- will insert/overwrite an entry in p_tgt_owner.STRM_TAB_CONTROL
    PROCEDURE add_tab_control (
        p_src_db 	IN     VARCHAR2,
        p_src_owner 	IN     VARCHAR2,
        p_src_table 	IN     VARCHAR2,
        p_tgt_owner 	IN     VARCHAR2,
        p_tgt_table 	IN     VARCHAR2,
        p_keep_dups 	IN     CHAR DEFAULT 'N',
        p_proc_flags 	IN     VARCHAR2 DEFAULT null );

    -- Packaged procedure refresh_col_controls
    -- will overwrite entries in p_tgt_owner.STRM_COL_DELETIONS
    -- and p_tgt_owner.STRM_COL_DIFFERENCES
    PROCEDURE refresh_col_controls (
        p_tgt_owner 	IN     VARCHAR2,
        p_tgt_table 	IN     VARCHAR2 DEFAULT NULL);

    -- Packaged procedure check_table_existence
    -- will raise an exception if tables listed in STRM_TAB_CONTROL
    -- do not exist in source or target schemas
    PROCEDURE check_table_existence (
        p_staging_owner 	IN     VARCHAR2);

    -- packaged procedure check_differences
    -- will raise an exception if critical column type differences exist
    -- between source and target for any staging tables
    PROCEDURE check_differences (
        p_staging_owner 	IN     VARCHAR2);

    -- Packaged procedure refresh_apply_keys
    -- will select not to compare old column values for staging tables during apply.
    PROCEDURE refresh_apply_keys (
        p_staging_owner 	IN     varchar2,
        p_tgt_table 		IN     VARCHAR2 DEFAULT NULL);



END MIS_TAB_CTRL_PKG;
/

show errors
