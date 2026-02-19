CREATE OR REPLACE PACKAGE AUDITDATA.AUDITDATA_CONV_PKG AS

/*
 *  NOMIS Audit Data Conversion code.
 *  
 *  Description:  	This script creates procedures to support
 *                      Audit data conversion for Prison-NOMIS release 1.0e.
 *  
 *                  This script should be compiled by the AUDITDATA user.
 *  
 *                      N.B. This package is dependent on the AUDITDATA_GEN_PKG package.
 *  
 *  Change History:	
 *          Version:  Date:	    Author:	    Description:	
 *
 *			1.0e.1	  15/01/26  D. Belton	Initial version for 1.0e audit based on AUD_STRM_PKG2
 */

    -- package version
    g_version 	 	VARCHAR2(20) := '1.0e.1';

    -- package level variable declarations
--    g_queue_owner 	VARCHAR2(30) := SYS_CONTEXT('USERENV', 'CURRENT_USER'); this would be right if the package was installed in ggint but its now in auditdata
    g_data_owner 	VARCHAR2(30) := 'AUDITDATA';
    g_ref_owner 	VARCHAR2(30) := 'AUDITREF';
    g_data_apply_name VARCHAR2(30) := 'AUDDTAPP';
    g_ref_apply_name  VARCHAR2(30) := 'AUDRFAPP';
    g_log_dir		varchar2(30) := 'AUD_ERRORLOG_DIR';
    g_binary_dir	varchar2(30) := 'AUD_BINARY_DIR';
    g_historic_days 	CONSTANT NUMBER := 793;


    -- define exceptions
    g_aud_conv_exception 	CONSTANT NUMBER := -20041;
    AUD_CONV_EXCEPTION 		EXCEPTION;
    PRAGMA EXCEPTION_INIT(AUD_CONV_EXCEPTION, -20041);

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

    -- Packaged function compareanydata
    -- compares 2 values stored as sys.anydata;
    -- returns true if they are equal, false if they different, null on an exception.
    FUNCTION compareanydata (
        anydata1 IN SYS.ANYDATA,
        anydata2 IN SYS.ANYDATA)
    RETURN BOOLEAN;


    -- Packaged function convertaddinfo
    -- does basic validation of audit_additional_info and, if valid, extracts IP address and 
    -- workstation name from it, swapping them around with the ip address and workstation values 
    -- supplied in the audit_client_ip_address and audit_client_workstation_name columns;
    -- caters for Citrix environments, where the values in the audit_client_ip adddress and 
    -- audit_client_workstation name will be that of the Citrix server, the end client ip address 
    -- and workstation name being embedded in the audit_additional_info column;
    -- returns true if audit_additional_info is valid, false if invalid, null on an exception.
    FUNCTION convertaddinfo(
    	p_addinfo_in IN VARCHAR2, 
        p_ipaddress_in IN VARCHAR2,
        p_workstation_in IN VARCHAR2,
        p_addinfo_out OUT VARCHAR2,
        p_ipaddress_out OUT VARCHAR2,
        p_workstation_out OUT VARCHAR2)
    RETURN BOOLEAN;


    -- Packaged function convert_OBJ_PRIVILEGE
    -- will convert a DBA_AUDIT_TRAIL.OBJ_PRIVILEGE value to user-friendly string
    FUNCTION convert_OBJ_PRIVILEGE (
        p_obj_priv in varchar2 ) 
    RETURN varchar2 RESULT_CACHE;

    -- Packaged function get_version
    -- will return a VARCHAR2 string containing a package version number
    FUNCTION get_version RETURN varchar2;


END AUDITDATA_CONV_PKG;
/

show errors
