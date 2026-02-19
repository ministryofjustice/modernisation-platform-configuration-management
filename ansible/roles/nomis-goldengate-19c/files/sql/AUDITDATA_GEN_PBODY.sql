CREATE OR REPLACE PACKAGE BODY AUDITDATA.AUDITDATA_GEN_PKG AS

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
        p_error_location in varchar2)
  IS
 	PRAGMA AUTONOMOUS_TRANSACTION;
  /*
  Summary
  ==============
  Logs errors encountered by audit_process_row procedure;
  Errors are written to the NOMIS audit database or, failing that, to a text file
  */
	v_audit_error_seq	number;
	v_fil   		UTL_FILE.file_type;
	v_dberror		boolean;
	v_filerror		boolean;
	v_dir			varchar2(30) := g_log_dir;
	v_filename		varchar2(100) := 'audit_errors_';
    v_timestamp 	timestamp(6) := systimestamp;
    v_timestamptz 	timestamp(6) with time zone := cast(v_timestamp as timestamp with time zone);
    v_text 		varchar2(4000) := substr(p_errmsg,1,4000);
  BEGIN
	v_dberror := false;
	v_filerror := false;
	BEGIN
		SELECT auditdata.audit_error_seq.nextval INTO v_audit_error_seq from dual;
        INSERT INTO auditdata.audit_error
		COLUMNS (
			audit_error_seq,
			error_datetime,
			error_code,
			error_msg,
			scn,
			object_name,
			command_type,
			target_object_name,
			target_date,
			commit_scn,
			lcr_source_time,
			error_location)
	  	VALUES (
			v_audit_error_seq,
			v_timestamptz,
            p_errcode,
            v_text,
            p_scn,
            p_object_name,
			p_command_type,
			p_target_object_name,
			p_target_date,
			p_commit_scn,
			p_source_time,
			p_error_location);
		COMMIT;
	EXCEPTION
		WHEN OTHERS THEN
			v_dberror := true;
	END;
	IF v_dberror = true THEN
		BEGIN
			v_filename := v_filename || TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS') || '.txt';
			v_fil := UTL_FILE.fopen (v_dir, v_filename, 'a', 4000);
			UTL_FILE.put_line (v_fil, 'Audit message processing error at  ' || TO_CHAR(v_timestamptz, 'DD-MM-YYYY HH24:MI:SS.FF TZH:TZM'));
			UTL_FILE.put_line (v_fil, 'SQLCODE: ' || NVL(TO_CHAR(p_errcode), ' '));
			UTL_FILE.put_line (v_fil, 'SQLERRM: ' || NVL(v_text, ' '));
			UTL_FILE.put_line (v_fil, 'SCN: ' || NVL(TO_CHAR(p_scn), ' '));
			UTL_FILE.put_line (v_fil, 'OBJECT: ' || NVL(p_object_name, ' '));
			UTL_FILE.put_line (v_fil, 'COMMAND TYPE: ' || NVL(p_command_type, ' '));
			UTL_FILE.put_line (v_fil, 'TARGET AUDIT TABLE: ' || NVL(p_target_object_name, ' '));
			UTL_FILE.put_line (v_fil, 'EFFECTIVE DATE: ' || NVL(TO_CHAR(p_target_date, 'DD-MM-YYYY HH24:MI:SS'), ' '));
			UTL_FILE.put_line (v_fil, 'COMMIT SCN: ' || NVL(TO_CHAR(p_commit_scn), ' '));
			UTL_FILE.put_line (v_fil, 'SOURCE_TIME: ' || NVL(TO_CHAR(p_source_time, 'DD-MM-YYYY HH24:MI:SS'), ' '));
			UTL_FILE.put_line (v_fil, 'ERROR LOCATION: ' || NVL(p_error_location, ' '));
			UTL_FILE.fclose (v_fil);
		EXCEPTION
         		WHEN OTHERS THEN
				v_filerror := true;
				UTL_FILE.fclose (v_fil);
		END;
	END IF;
  EXCEPTION
	WHEN OTHERS THEN
		v_filerror := true;
  END;
  
  PROCEDURE log_audit_error (
    p_location 		IN     varchar2 DEFAULT 'AUDIT',
    p_src_time 		IN     date     DEFAULT NULL,
    p_src_object 	IN     varchar2 DEFAULT NULL,
    p_tgt_object	IN     varchar2 DEFAULT NULL,
    p_tgt_date 		IN     date     DEFAULT NULL,
    p_command_type	IN     varchar2 DEFAULT NULL,
    p_row_scn 		IN     number   DEFAULT NULL,
    p_commit_scn 	IN     number   DEFAULT NULL,
    p_error_code 	IN     number   DEFAULT NULL,
    p_message 	 	IN     varchar2 DEFAULT NULL
  ) IS
  -- will insert entries in g_data_owner.AUDIT_ERROR
  BEGIN
    audit_log_error (
      	p_errcode => p_error_code,
      	p_errmsg => p_message,
        p_scn => p_row_scn,
        p_object_name => p_src_object,
        p_command_type => p_command_type,
        p_target_object_name => p_tgt_object,
        p_target_date => p_tgt_date,
        p_commit_scn => p_commit_scn,
        p_source_time => p_src_time,
        p_error_location => p_location);
  END;
  
END AUDITDATA_GEN_PKG;
/
