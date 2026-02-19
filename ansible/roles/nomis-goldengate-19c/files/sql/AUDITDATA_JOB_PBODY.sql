CREATE OR REPLACE PACKAGE BODY AUDITDATA.AUDITDATA_JOB_PKG AS

/*
 *  NOMIS AuditData GoldenGate code.
 *  
 *  Description:  	This script creates procedures to support
 *                      Oracle job processes for Prison-NOMIS.
 *  
 *                  This script should be compiled by the AUDITDATA user.
 *  
 *  Change History:	
 *          Version:  Date:	    Author:	    Description:	
 *
 *			1.0e.1	  15/01/26  D. Belton	Initial version for 1.0e audit
 */

  -- packaged function get_version
  -- will return a VARCHAR2 string containing a package version number
  FUNCTION get_version RETURN varchar2 IS
  BEGIN
    return g_version;
  END;


  FUNCTION get_queue_name(
    p_staging_owner IN varchar2
  ) RETURN varchar2 RESULT_CACHE
  IS
  -- local function get_queue_name returns the queue name
  -- for the supplied staging table owner
  BEGIN
    return 'OGGQ$'||p_staging_owner;
  END;


  FUNCTION getOffId (
    icolname  IN varchar2,
    icolvalue IN varchar2
  ) RETURN VARCHAR2
  IS
  /*
  Summary
  ==============
  Retrieves offender id associated with column values in NOMIS audit database
  */
	refid 		number := null;
        colname 	varchar2(32) := lower(substr(trim(icolname),1,32));
        colvalue 	varchar2(200) := substr(trim(icolvalue),1,200);

    FUNCTION getOffId1 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
	from   AUDITREF.offenders o
	where  o.offender_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId2 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
	from   AUDITREF.offenders o,
	       AUDITREF.offender_bookings b
	where  b.offender_id =  o.offender_id
	and    b.offender_book_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId3 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings, AUDITREF.offender_cases)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
	from   AUDITREF.offenders o,
	       AUDITREF.offender_bookings b, 
	       AUDITREF.offender_cases c
	where  o.offender_id =  b.offender_id
	and    b.offender_book_id = c.offender_book_id
	and    c.case_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId4 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings, AUDITREF.offender_program_profiles)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
	from   AUDITREF.offenders o,
	       AUDITREF.offender_bookings b, 
	       AUDITREF.offender_program_profiles r
	where  o.offender_id =  b.offender_id
	and    b.offender_book_id = r.offender_book_id
	and    r.off_prgref_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId5 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings, AUDITREF.offender_curfews)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
        from   AUDITREF.offenders o, 
	       AUDITREF.offender_bookings b, 
	       AUDITREF.offender_curfews c
	where  o.offender_id =  b.offender_id
	and    b.offender_book_id = c.offender_book_id
	and    c.offender_curfew_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId6 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings, 
	       AUDITREF.offender_curfews, AUDITREF.hdc_request_referrals)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
        from   AUDITREF.offenders o, 
	       AUDITREF.offender_bookings b, 
	       AUDITREF.offender_curfews c, 
	       AUDITREF.hdc_request_referrals h
	where  o.offender_id = b.offender_id
	and    b.offender_book_id = c.offender_book_id
	and    c.offender_curfew_id = h.offender_curfew_id
	and    h.hdc_request_referral_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId7 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_deductions)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
        from   AUDITREF.offenders o, 
	       AUDITREF.offender_deductions d
	where  o.offender_id = d.offender_id
	and    d.offender_deduction_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId8 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings, AUDITREF.offender_case_notes)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
        from   AUDITREF.offenders o, 
	       AUDITREF.offender_bookings b, 
	       AUDITREF.offender_case_notes n
	where  o.offender_id = b.offender_id
	and    b.offender_book_id = n.offender_book_id
	and    n.case_note_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId9 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings,
	       AUDITREF.agency_incident_parties, AUDITREF.oic_hearings)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
        from   AUDITREF.offenders o, 
	       AUDITREF.offender_bookings b, 
	       AUDITREF.agency_incident_parties p, 
	       AUDITREF.oic_hearings h
	where  o.offender_id = b.offender_id
	and    b.offender_book_id = p.offender_book_id
	and    p.oic_incident_id = h.oic_incident_id
	and    h.oic_hearing_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId10 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings, AUDITREF.agency_incident_parties)
    IS
	refid 		number := null;
    BEGIN
        -- function will return null if multiple values occur
	select o.offender_id into refid
	from   AUDITREF.offenders o,
	       AUDITREF.offender_bookings b, 
	       AUDITREF.agency_incident_parties p
	where  o.offender_id =  b.offender_id
	and    b.offender_book_id = p.offender_book_id
	and    p.agency_incident_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
	WHEN TOO_MANY_ROWS THEN
  		RETURN null;
    END;
    FUNCTION getOffId11 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings,
	       AUDITREF.offender_curfews, AUDITREF.curfew_addresses)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
	from   AUDITREF.offenders o,
	       AUDITREF.offender_bookings b, 
	       AUDITREF.offender_curfews c, 
	       AUDITREF.curfew_addresses a
	where  o.offender_id =  b.offender_id
	and    b.offender_book_id = c.offender_book_id
	and    c.offender_curfew_id = a.offender_curfew_id
	and    a.curfew_address_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId12 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings, AUDITREF.offender_health_problems)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
	from   AUDITREF.offenders o,
	       AUDITREF.offender_bookings b, 
	       AUDITREF.offender_health_problems p
	where  o.offender_id =  b.offender_id
	and    b.offender_book_id = p.offender_book_id
	and    p.offender_health_problem_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId13 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings, AUDITREF.offender_contact_persons)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
	from   AUDITREF.offenders o,
	       AUDITREF.offender_bookings b, 
	       AUDITREF.offender_contact_persons p
	where  o.offender_id =  b.offender_id
	and    b.offender_book_id = p.offender_book_id
	and    p.offender_contact_person_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId14 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings, AUDITREF.offender_ppty_containers)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
	from   AUDITREF.offenders o,
	       AUDITREF.offender_bookings b, 
	       AUDITREF.offender_ppty_containers p
	where  o.offender_id =  b.offender_id
	and    b.offender_book_id = p.offender_book_id
	and    p.property_container_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId15 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings, AUDITREF.offender_visit_orders)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
	from   AUDITREF.offenders o,
	       AUDITREF.offender_bookings b, 
	       AUDITREF.offender_visit_orders v
	where  o.offender_id =  b.offender_id
	and    b.offender_book_id = v.offender_book_id
	and    v.offender_visit_order_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId16 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings,
	       AUDITREF.offender_cases, AUDITREF.offender_charges)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
	from   AUDITREF.offenders o, 
	       AUDITREF.offender_bookings b, 
	       AUDITREF.offender_cases c, 
	       AUDITREF.offender_charges oc
	where  o.offender_id =  b.offender_id
	and    b.offender_book_id = c.offender_book_id
	and    c.case_id = oc.case_id
	and    oc.offender_charge_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId17 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings, AUDITREF.orders)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
	from   AUDITREF.offenders o, 
	       AUDITREF.offender_bookings b, 
	       AUDITREF.orders o2
	where  o.offender_id =  b.offender_id
	and    b.offender_book_id = o2.offender_book_id
	and    o2.order_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;
    FUNCTION getOffId18 (
        icolvalue IN varchar2
    ) RETURN number RESULT_CACHE
    RELIES_ON (AUDITREF.offenders, AUDITREF.offender_bookings, AUDITREF.orders)
    IS
	refid 		number := null;
    BEGIN
	select o.offender_id into refid
	from   AUDITREF.offenders o, 
	       AUDITREF.offender_bookings b, 
	       AUDITREF.offender_rehab_decisions d
	where  o.offender_id =  b.offender_id
	and    b.offender_book_id = d.offender_book_id
	and    d.offender_rehab_decision_id = to_number(icolvalue);
        RETURN refid;
    EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
    END;

  BEGIN
    if colvalue is null 
    or trim(colvalue) = '' then
		refid := null;
    else

	case
		when colname like '%offender_id' 
		or colname like '%offender_id_1'
		or colname like '%offender_id_2' then
			refid := getOffId1(colvalue);
		when colname like '%offender_book_id%' 
		or colname in ('offender_booking_id')then
			refid := getOffId2(colvalue);
		when colname = 'case_id' then
			refid := getOffId3(colvalue);
		when colname = 'off_prgref_id' then
			refid := getOffId4(colvalue);
		when colname like 'offender_curfew_id' then
			refid := getOffId5(colvalue);
		when colname like '%hdc_request_referral_id' then
			refid := getOffId6(colvalue);
		when colname = 'offender_deduction_id' then
			refid := getOffId7(colvalue);
		when colname = 'case_note_id' then
			refid := getOffId8(colvalue);
		when colname = 'oic_hearing_id' then
			refid := getOffId9(colvalue);
		when colname = 'agency_incident_id' then
                        -- function will return null if multiple values occur
			refid := getOffId10(colvalue);
		when colname = 'curfew_address_id' then
			refid := getOffId11(colvalue);
		when colname = 'offender_health_problem_id' then
			refid := getOffId12(colvalue);
		when colname = 'offender_contact_person_id' then
			refid := getOffId13(colvalue);
		when colname = 'property_container_id' then
			refid := getOffId14(colvalue);
		when colname = 'offender_visit_order_id' then
			refid := getOffId15(colvalue);
		when colname = 'offender_charge_id' then
			refid := getOffId16(colvalue);
		when colname = 'order_id' then
			refid := getOffId17(colvalue);
		when colname = 'offender_rehab_decision_id' then
			refid := getOffId18(colvalue);
	 else
		refid := null;
	 end case;

    end if;

    return refid;
  EXCEPTION
	WHEN NO_DATA_FOUND THEN
  		RETURN null;
	WHEN TOO_MANY_ROWS THEN
  		RETURN null;
 	WHEN OTHERS THEN
  		RETURN null;
  END;

  PROCEDURE populate_offender_refs (
    p_table_row_limit	IN     NUMBER DEFAULT 2000000,
    p_commit_unit_size	IN     NUMBER DEFAULT 1000
  ) IS
  PRAGMA AUTONOMOUS_TRANSACTION;
  -- procedure populate_offender_refs
  -- will insert offender cross-reference entries for up to p_table_row_limit
  -- rows from AUDITDATA.AUDIT_TABLE, based on values in AUDIT_COLUMN

    l_start_seq 	number := 0;
    l_start_time 	date := sysdate-g_historic_days;
    l_limit_scn 	number := 0;
    l_limit_time 	date := sysdate;
    l_source_time 	date := null;
    l_source_object 	varchar2(30) := null;
    l_queue_name 	varchar2(30) := get_queue_name(g_data_apply_name);

  BEGIN

    -- get highest existing sequence with offender references
    l_source_object := 'AUDIT_OFFENDER_REF';
    select nvl(max(audit_table_seq),0), nvl(max(lcr_source_time),sysdate-g_historic_days)
    into   l_start_seq, l_start_time
    from   auditdata.AUDIT_OFFENDER_REF;

    -- get low watermark for transactions applied to reference tables
    l_source_object := 'ALL_APPLY_PROGRESS';
    select min(p.applied_message_number), min(nvl(p.applied_message_create_time,sysdate))
    into   l_limit_scn, l_limit_time
    from   all_apply_progress p, all_apply a
    where  p.apply_name = a.apply_name
    --and    a.queue_owner = g_queue_owner
    and    a.queue_name = l_queue_name;

    -- loop for audit table rows with sequence higher than selected above
    l_source_object := 'AUDIT_TABLE';
    FOR c_table_row IN
       (select audit_table_seq, lcr_source_time, rownum
        from  (select audit_table_seq, lcr_source_time
               from   auditdata.AUDIT_TABLE
               where  audit_table_seq > l_start_seq
               and    lcr_source_time >= l_start_time
               and    lcr_source_time <= l_limit_time
               and    lcr_commit_scn <= l_limit_scn
               order by audit_table_seq, lcr_source_time)
        where  rownum <= p_table_row_limit)
    LOOP
        l_source_time := c_table_row.lcr_source_time;
        l_source_object := 'AUDIT_COLUMN';
        -- derive offender references from audit column values
        insert into auditdata.AUDIT_OFFENDER_REF
           (offender_id, audit_table_seq, lcr_source_time)
        select distinct getOffId(C.LCR_COLUMN_NAME,
                   CONVERT_ANYDATA_TO_VARCHAR2(C.LCR_COLUMN_VALUE)),
                   C.AUDIT_TABLE_SEQ, C.LCR_SOURCE_TIME
        from   AUDITDATA.AUDIT_COLUMN C
        where  getOffId(C.LCR_COLUMN_NAME,
                   CONVERT_ANYDATA_TO_VARCHAR2(C.LCR_COLUMN_VALUE)) is not null
        and    C.AUDIT_TABLE_SEQ = c_table_row.audit_table_seq
        and    C.LCR_SOURCE_TIME = l_source_time;

        -- commit regularly
        IF mod(c_table_row.rownum, p_commit_unit_size) = 0 THEN
            commit;
        END IF;
    END LOOP;

    commit;

  EXCEPTION
    WHEN OTHERS THEN
        log_audit_error ('populate_offender_refs', p_src_time => l_source_time,
                p_src_object => l_source_object, p_tgt_object => 'AUDIT_OFFENDER_REF',
                p_command_type => null, p_row_scn => null, p_commit_scn => null,
                p_error_code => SQLCODE, p_message => SQLERRM);
        RAISE;
  END;


  PROCEDURE export_binary_data (
    p_lcr_commit_scn 	in     number
  ) IS
  /*
  Summary
  ==============
  Extracts binary data (images and documents) for a specified transactrion from the NOMIS audit database;
  Requires creation of g_binary_dir DIRECTORY to receive output files;
  */

    e_missing_parameter	exception;

    v_lcr_commit_scn		auditdata.audit_table.lcr_commit_scn%type := null;
    v_lcr_source_time		auditdata.audit_table.lcr_source_time%type := null;
    v_lcr_object_name		auditdata.audit_table.lcr_object_name%type := null;
    v_lcr_column_name		auditdata.audit_column.lcr_column_name%type := null;
    v_lcr_column_value		auditdata.audit_column.lcr_column_value%type := null;

    v_lcr_commit_scn_prev	auditdata.audit_table.lcr_commit_scn%type := 0;
    v_lcr_object_name_prev	auditdata.audit_table.lcr_object_name%type := '';
    v_lcr_column_name_prev	auditdata.audit_column.lcr_column_name%type := '';

    type v_blob_tab is table of blob index by binary_integer;
    v_blobs			v_blob_tab;
    v_blob_idx			number := 0;
    v_rtn			number;
    v_rawblob			raw(32767);
    v_blob_len			number;
    type v_file_name_tab is table of varchar2(100) index by binary_integer;
    v_file_names		v_file_name_tab;
    v_output_file		UTL_FILE.FILE_TYPE;
    v_buffer    		raw(32767);
    v_amount    		binary_integer := 32767;
    v_pos       		integer := 1;

    --v3: select on commit scn
    CURSOR c_chunks (p_lcr_commit_scn IN number) IS
	SELECT 	t.lcr_commit_scn, t.lcr_source_time, t.lcr_object_name,
		c.lcr_column_name, c.lcr_column_value
	FROM auditdata.audit_table t, auditdata.audit_column c
	WHERE t.audit_table_seq = c.audit_table_seq
	AND t.lcr_command_type = 'LOB WRITE'
	AND c.lcr_column_value.GETTYPENAME() = 'SYS.RAW'
	AND t.lcr_commit_scn = p_lcr_commit_scn
	ORDER BY t.lcr_commit_scn, t.audit_table_seq;

  BEGIN

    --validate input
    --DBMS_OUTPUT.PUT_LINE('Validating input...');
    --v3: argument is now numeric
    IF p_lcr_commit_scn IS NULL
    OR p_lcr_commit_scn = 0 
    THEN
    	RAISE e_missing_parameter;
    END IF;

    --retrieve binary chunks
    --DBMS_OUTPUT.PUT_LINE('Retrieving data...');
    OPEN c_chunks(p_lcr_commit_scn);
    LOOP
        FETCH c_chunks
        INTO v_lcr_commit_scn, v_lcr_source_time, v_lcr_object_name, v_lcr_column_name, v_lcr_column_value;
        EXIT WHEN c_chunks%NOTFOUND;
        v_rtn := v_lcr_column_value.GETRAW(v_rawblob);
        IF v_lcr_commit_scn <> v_lcr_commit_scn_prev
        OR v_lcr_object_name <> v_lcr_object_name_prev
        OR v_lcr_column_name <> v_lcr_column_name_prev 
        THEN
            v_blob_idx := v_blob_idx + 1;
            v_blobs(v_blob_idx) := v_rawblob;
            v_file_names(v_blob_idx) := TO_CHAR(p_lcr_commit_scn) || '_' || v_lcr_object_name || '_' ||
                v_lcr_column_name || '_' || TO_CHAR(v_lcr_source_time, 'YYYYMMDD_HH24MISS');
            v_lcr_commit_scn_prev := v_lcr_commit_scn;
            v_lcr_object_name_prev := v_lcr_object_name;
            v_lcr_column_name_prev := v_lcr_column_name;
        ELSE
            DBMS_LOB.APPEND(v_blobs(v_blob_idx), v_rawblob);
        END IF;
    END LOOP;

    --DBMS_OUTPUT.PUT_LINE(TO_CHAR(v_blob_idx) || ' images/documents retrieved...');

    --create output files
    FOR idx IN 1..v_blobs.count
    LOOP
        v_output_file := UTL_FILE.fopen(g_binary_dir, v_file_names(idx),'wb', 32767);
        v_blob_len := DBMS_LOB.GETLENGTH(v_blobs(idx));
        v_pos := 1;
        WHILE v_pos < v_blob_len LOOP
            DBMS_LOB.read(v_blobs(idx), v_amount, v_pos, v_buffer);
            UTL_FILE.put_raw(v_output_file, v_buffer, TRUE);
            v_pos := v_pos + v_amount;
        END LOOP;
        --close the file.
        UTL_FILE.fclose(v_output_file);
    END LOOP;
    
    -- log completion
    log_audit_error ('export_binary_data', p_src_time => v_lcr_source_time,
        p_src_object => null, p_tgt_object => null,
        p_command_type => null, p_row_scn => null, p_commit_scn => p_lcr_commit_scn,
        p_error_code => SQLCODE, p_message => v_blobs.count || ' binary file(s) created.');

  EXCEPTION
    WHEN e_missing_parameter THEN
        log_audit_error ('export_binary_data', p_src_time => null,
                p_src_object => null, p_tgt_object => null,
                p_command_type => null, p_row_scn => null, p_commit_scn => p_lcr_commit_scn,
                p_error_code => SQLCODE, p_message => 'No Commit SCN specified');
    WHEN OTHERS THEN
        log_audit_error ('export_binary_data', p_src_time => v_lcr_source_time,
                p_src_object => v_lcr_object_name, p_tgt_object => null,
                p_command_type => null, p_row_scn => null, p_commit_scn => p_lcr_commit_scn,
                p_error_code => SQLCODE, p_message => SQLERRM);
  END;


END AUDITDATA_JOB_PKG;
/

show errors
