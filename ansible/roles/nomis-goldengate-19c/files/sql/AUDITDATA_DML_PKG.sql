CREATE OR REPLACE PACKAGE AUDITDATA.AUDITDATA_DML_PKG AS

    -- package version
    g_version 	 	VARCHAR2(20) := '1.0e.1';

/*
 *  NOMIS AuditData GoldenGate code.
 *  
 *  Description:  	This script creates procedures to support
 *                      Oracle GoldenGate processes for Prison-NOMIS.
 *  
 *                  This script should be compiled by the GGADMIN user.
 *  
 *  Change History:	
 *          Version:  Date:	    Author:	    Description:	
 *
 *			1.0e.1	  15/01/26  D. Belton	Initial version for 1.0e audit based on AUD_STRM_PKG2
 */

    -- package level variable declarations
--    g_queue_owner 	VARCHAR2(30) := USER; this would be right if the package was installed in ggint but its now in auditdata
    g_queue_owner 	VARCHAR2(30) := 'GGINT';
    g_source_owner 	VARCHAR2(30) := 'OMS_OWNER';
    g_capture_name 	VARCHAR2(30) := 'AUDDTCAP';
    g_consumer_name 	VARCHAR2(30) := 'OGG$CAP_'||g_capture_name;
--    g_capture_rs_name 	VARCHAR2(30) := 'RS_C_OMS_AUDIT';
--    g_capture_nrs_name 	VARCHAR2(30) := 'NRS_C_OMS_AUDIT';
    g_replicat_name VARCHAR2(30) := 'AUDDTAPP';
    g_apply_name 	VARCHAR2(30) := 'OGG$'||g_replicat_name;
    g_apply_rs_name VARCHAR2(30) := 'RS_A_'||g_replicat_name;
    g_apply_nrs_name VARCHAR2(30) := 'NRS_A_'||g_replicat_name;
    g_data_owner 	VARCHAR2(30) := 'AUDITDATA';
--    g_queue_name 	VARCHAR2(30) := 'Q_AUDITDATA';
    g_handler_name 	VARCHAR2(30) := 'AUDIT_PROCESS_ROW';

    -- Type definitions for lists of information
    TYPE owner_list IS TABLE OF all_tables.owner%type;
    TYPE table_list IS TABLE OF all_tables.table_name%type;
    TYPE operations_list IS TABLE OF all_apply_dml_handlers.operation_name%type;

    -- sleep before retry period: times in seconds to wait after timeout before retry
    g_sleep1 	NUMBER := 180;
    g_sleep2 	NUMBER := 540;

    -- define exceptions
    AUD_STREAMS_EXCEPTION EXCEPTION;
    PRAGMA EXCEPTION_INIT(AUD_STREAMS_EXCEPTION, -20020);
    AUD_STREAMS_QUEUE_EXCEPTION EXCEPTION;
    PRAGMA EXCEPTION_INIT(AUD_STREAMS_QUEUE_EXCEPTION, -20021);

    -- define error conditions for exception handling
    rule_set_exists EXCEPTION;
    PRAGMA EXCEPTION_INIT(rule_set_exists, -24153);
    timeout_stopping_process EXCEPTION;
    PRAGMA EXCEPTION_INIT(timeout_stopping_process, -26672);
    cannot_alter_process EXCEPTION;
    PRAGMA EXCEPTION_INIT(cannot_alter_process, -26666);

    -- Packaged procedure audit_process_row
    -- writes details of changes made to NOMIS database to audit database
    PROCEDURE audit_process_row (p_any in anydata);

    -- Packaged procedure apply_dml_conf
    -- sets all dml handlers for all tables in selected schema
    -- NB if the assemble_lobs parameter needs changing after the initial running of this script,
    -- it must be done one table and operation at a time, as this script won't change it.
    PROCEDURE apply_dml_conf;
    
    -- Packaged procedure apply_dml_deconf
    -- will remove DML handlers for audit apply process
    PROCEDURE apply_dml_deconf;

    -- Packaged procedure maintain_module_config
    -- maintains configuration for modules to be excluded from the recording
    -- of C-NOMIS business data changes on the NOMIS Audit database
    PROCEDURE maintain_module_config (
        p_module_name in varchar2,
        p_exclude_ind in char);

    -- Packaged procedure stop_capture stops audit capture process
--    PROCEDURE stop_capture (p_force IN BOOLEAN  DEFAULT FALSE);

    -- Packaged procedure start_capture starts audit capture process
--    PROCEDURE start_capture;

    -- Packaged procedure stop_apply stops audit apply process
    PROCEDURE stop_apply (p_force IN BOOLEAN DEFAULT FALSE);

    -- Packaged procedure start_apply starts audit apply process
    -- first resets apply handlers and checks for errors
    PROCEDURE start_apply (p_refresh_flag IN BOOLEAN DEFAULT TRUE);

    -- Packaged function get_version
    -- will return a VARCHAR2 string containing a package version number
    FUNCTION get_version RETURN varchar2;

END AUDITDATA_DML_PKG;
/

show errors

