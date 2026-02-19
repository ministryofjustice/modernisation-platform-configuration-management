CREATE OR REPLACE PACKAGE MIS_GG_CTRL_PKG AUTHID DEFINER AS
/*
 *  NOMIS MIS Goldengate code.
 *  
 *  Description:  	This script creates procedures to support
 *                      Oracle Goldengate control processes for Prison-NOMIS release 1.0e.
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

    -- Packaged function apply_process_error_count returns the number of apply processes
    -- for a particular staging table owner (if supplied) that have error status
    FUNCTION apply_process_error_count(
        p_staging_owner 	IN     varchar2 DEFAULT NULL,
        p_ignore_inactive 	IN     boolean DEFAULT TRUE
    ) RETURN number;

    -- Packaged procedure set_stop_points
    -- sets or clears stop points for all capture and apply processes
    -- associated with a particular staging table owner.
    PROCEDURE set_stop_points (
        p_staging_owner IN     varchar2,
        p_points_set 	OUT    boolean);

    -- Packaged procedure wait_stop_points
    -- waits for all capture processes
    -- associated with a particular staging table owner to stop.
    PROCEDURE wait_stop_points (
        p_staging_owner IN     varchar2,
        p_continue 	OUT    boolean);

END MIS_GG_CTRL_PKG;
/

show errors
