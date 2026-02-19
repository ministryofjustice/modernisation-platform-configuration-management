CREATE OR REPLACE PACKAGE AUDITDATA.AUDITDATA_GEN_PKG AS

    -- package version
    g_version 	 	VARCHAR2(20) := '1.0e.1';

/*
 *  NOMIS AuditData GoldenGate code.
 *  
 *  Description:  	This script creates procedures to support
 *                      Oracle GoldenGate processes for Prison-NOMIS.
 *  
 *                  This script should be compiled by the AUDITDATA user.
 *  
 *  Change History:	
 *          Version:  Date:	    Author:	    Description:	
 *
 *			1.0e.1	  15/01/26  D. Belton	Initial version for 1.0e audit based on AUD_GEN_PKG1
 */

    -- package level variable declarations
    g_data_owner 	VARCHAR2(30) := 'AUDITDATA';
    g_log_dir		varchar2(30) := 'AUD_ERRORLOG_DIR';

    -- will insert entries in g_data_owner.AUDIT_ERROR or, failing that, to a text file.
    PROCEDURE audit_log_error (
      	p_errcode in pls_integer,
      	p_errmsg in varchar2,
        p_scn in number,
        p_object_name in varchar2,
        p_command_type in varchar2,
        p_target_object_name in varchar2,
        p_target_date in date,
        p_commit_scn in number,
        p_source_time in date,
        p_error_location in varchar2);

    PROCEDURE log_audit_error (
        p_location 	    IN     varchar2 DEFAULT 'AUDIT',
        p_src_time 	    IN     date     DEFAULT NULL,
        p_src_object 	IN     varchar2 DEFAULT NULL,
        p_tgt_object	IN     varchar2 DEFAULT NULL,
        p_tgt_date 	    IN     date     DEFAULT NULL,
        p_command_type	IN     varchar2 DEFAULT NULL,
        p_row_scn 	    IN     number   DEFAULT NULL,
        p_commit_scn 	IN     number   DEFAULT NULL,
        p_error_code 	IN     number   DEFAULT NULL,
        p_message 	    IN     varchar2 DEFAULT NULL);

END AUDITDATA_GEN_PKG;
/
