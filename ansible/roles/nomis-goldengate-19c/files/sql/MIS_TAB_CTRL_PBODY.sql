CREATE OR REPLACE PACKAGE BODY MIS_TAB_CTRL_PKG AS
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

  FUNCTION get_version RETURN varchar2 IS
  -- packaged function get_version
  -- will return a VARCHAR2 string containing a package version number
  BEGIN
    return g_version;
  END;



  PROCEDURE set_col_deletions (
    p_src_db 		IN     VARCHAR2,
    p_src_owner 	IN     VARCHAR2,
    p_src_table 	IN     VARCHAR2,
    p_tgt_owner 	IN     VARCHAR2,
    p_tgt_table 	IN     VARCHAR2,
    p_proc_flags 	IN     VARCHAR2 DEFAULT ''
  ) IS
  -- local procedure set_col_deletions
  -- will insert/overwrite entries in p_tgt_owner.STRM_COL_DELETIONS

    l_plsql 	varchar2(2000); 
    l_plsql2	varchar2(2000); 
    l_col_list	mis_gen_pkg.object_list;
    l_dtyp_str	varchar2(200) := '''NONE''';
    l_src_db	varchar2(128) := mis_gen_pkg.strip_input(p_src_db,128);
    l_src_owner	varchar2(30) := mis_gen_pkg.strip_input(p_src_owner,30);
    l_tgt_owner	varchar2(30) := mis_gen_pkg.strip_input(p_tgt_owner,30);

  BEGIN

    -- remove old STRM_COL_DELETIONS entries (if any)
    l_plsql := 'delete from ' || l_tgt_owner || '.STRM_COL_DELETIONS ' ||
                'where tgt_table = :tgt_table';
    execute immediate l_plsql
    using p_tgt_table;

    -- set data types to be excluded
    IF instr(p_proc_flags, 'LONG') > 0 THEN
        l_dtyp_str := '''NONE''';
    ELSIF instr(p_proc_flags, 'LOB') > 0 THEN
        l_dtyp_str := '''LONG'',''LONG RAW''';
    ELSE
        l_dtyp_str := '''BLOB'',''CLOB'',''LONG'',''LONG RAW''';
    END IF;

    -- determine column names for new STRM_COL_DELETIONS entries
    l_plsql2 := 'select sc.column_name ' ||
                  'from all_tab_columns@' || l_src_db || ' sc ' ||
                 'where sc.owner = :src_owner ' ||
                   'and sc.table_name = :src_table ' ||
                   'and ( sc.data_type in (' || l_dtyp_str || ') ' ||
                      'or not exists ' ||
                        '(select null ' ||
                           'from all_tab_columns tc ' ||
                          'where tc.column_name = sc.column_name ' ||
                            'and tc.owner = :tgt_owner ' ||
                            'and tc.table_name = :tgt_table))';

    execute immediate l_plsql2 bulk collect into l_col_list
    using l_src_owner, p_src_table, l_tgt_owner, p_tgt_table;

    -- add new STRM_COL_DELETIONS entries
    l_plsql := 'insert into ' || l_tgt_owner || '.STRM_COL_DELETIONS ' ||
               '(TGT_TABLE, SRC_COLUMN) VALUES ' ||
               '(:tgt_table, :src_column)';

    FOR i in 1..l_col_list.count
    LOOP
        execute immediate l_plsql
        using p_tgt_table, l_col_list(i);
    END LOOP;

  END;

  PROCEDURE set_col_differences (
    p_src_db 		IN     VARCHAR2,
    p_src_owner 	IN     VARCHAR2,
    p_src_table 	IN     VARCHAR2,
    p_tgt_owner 	IN     VARCHAR2,
    p_tgt_table 	IN     VARCHAR2
  ) IS
  -- local procedure set_col_differences
  -- will insert/overwrite entries in p_tgt_owner.STRM_COL_DIFFERENCES

    l_plsql 	varchar2(2000); 
    l_plsql2	varchar2(2000); 
    l_col_list	mis_gen_pkg.object_list;
    l_src_db	varchar2(128) := mis_gen_pkg.strip_input(p_src_db,128);
    l_src_owner	varchar2(30) := mis_gen_pkg.strip_input(p_src_owner,30);
    l_tgt_owner	varchar2(30) := mis_gen_pkg.strip_input(p_tgt_owner,30);

    TYPE data_type_list IS TABLE OF all_tab_columns.data_type%type;
    TYPE data_length_list IS TABLE OF all_tab_columns.data_length%type;
    TYPE nullable_list IS TABLE OF all_tab_columns.nullable%type;

    l_src_dtyp	data_type_list;
    l_src_dlen	data_length_list;
    l_src_null	nullable_list;
    l_tgt_dtyp	data_type_list;
    l_tgt_dlen	data_length_list;
    l_tgt_null	nullable_list;

    l_abort 	varchar2(1);

    FUNCTION base_type (p_typ IN VARCHAR2)
    RETURN VARCHAR2 IS
        l_pos INTEGER := instr(p_typ, '(');
    BEGIN
        IF l_pos > 0 THEN
            RETURN substr(p_typ, 1, l_pos-1);
        ELSE
            RETURN p_typ;
        END IF;
    END;

  BEGIN

    -- remove old STRM_COL_DIFFERENCES entries (if any)
    l_plsql := 'delete from ' || l_tgt_owner || '.STRM_COL_DIFFERENCES ' ||
                'where tgt_table = :tgt_table';
    execute immediate l_plsql
    using p_tgt_table;

    -- determine column names for new STRM_COL_DIFFERENCES entries
    l_plsql2 := 'select sc.column_name, ' ||
                       'sc.data_type, ' ||
                       'sc.data_length, ' ||
                       'sc.nullable, ' ||
                       'tc.data_type, ' ||
                       'tc.data_length, ' ||
                       'tc.nullable ' ||
                  'from all_tab_columns@' || l_src_db || ' sc, ' ||
                       'all_tab_columns tc ' ||
                 'where sc.owner = :src_owner ' ||
                   'and sc.table_name = :src_table ' ||
                   'and tc.owner = :tgt_owner ' ||
                   'and tc.table_name = :tgt_table ' ||
                   'and tc.column_name = sc.column_name ' ||
                   'and (   tc.data_type != sc.data_type ' ||
                        'or tc.data_length != sc.data_length ' ||
                        'or tc.nullable != sc.nullable) ' ||
                'union ' ||
                'select tc.column_name, ' ||
                       'null, ' ||
                       'null, ' ||
                       'null, ' ||
                       'tc.data_type, ' ||
                       'tc.data_length, ' ||
                       'tc.nullable ' ||
                  'from all_tab_columns tc ' ||
                 'where tc.owner = :tgt_owner ' ||
                   'and tc.table_name = :tgt_table ' ||
                   'and tc.column_name != ''MIS_LOAD_ID'' ' ||
                   'and tc.column_name != ''MIS_SOURCE_TIME'' ' ||
                   'and tc.column_name != ''MIS_COMMAND_FLAG'' ' ||
                   'and tc.column_name != ''MIS_SCN'' ' ||
                   'and not exists ' ||
                       '(select null ' ||
                          'from all_tab_columns@' || l_src_db || ' sc ' ||
                         'where sc.column_name = tc.column_name ' ||
                           'and sc.owner = :src_owner ' ||
                           'and sc.table_name = :src_table)';

    execute immediate l_plsql2 bulk collect into l_col_list,
        l_src_dtyp, l_src_dlen, l_src_null, l_tgt_dtyp, l_tgt_dlen, l_tgt_null
    using l_src_owner, p_src_table, l_tgt_owner, p_tgt_table,
          l_tgt_owner, p_tgt_table, l_src_owner, p_src_table;

    -- add new STRM_COL_DIFFERENCES entries
    l_plsql := 'insert into ' || l_tgt_owner || '.STRM_COL_DIFFERENCES ' ||
               '(TGT_TABLE, SRC_COLUMN, ' ||
                'SRC_DATA_TYPE, SRC_DATA_LENGTH, SRC_NULLABLE, ' ||
                'TGT_DATA_TYPE, TGT_DATA_LENGTH, TGT_NULLABLE, ' ||
                'ABORT_FLAG) VALUES ' ||
               '(:tgt_table, :src_column, ' ||
                ':src_data_type, :src_data_length, :src_nullable, ' ||
                ':tgt_data_type, :tgt_data_length, :tgt_nullable, ' ||
                ':abort_flag)';

    FOR i in 1..l_col_list.count
    LOOP
        -- determine severity of differences
        l_abort := null;
        IF ((l_src_null(i) IS NULL) AND (l_tgt_null(i) = 'N')) THEN
            -- target has not null column not present in source
            l_abort := 'Y';
        ELSIF ((l_src_null(i) = 'Y') AND (l_tgt_null(i) = 'N')) THEN
            -- target has not null column that is nullable in source
            l_abort := 'Y';
        ELSIF (base_type(l_src_dtyp(i)) <> base_type(l_tgt_dtyp(i))) THEN
            IF (l_src_dtyp(i) = 'LONG' AND l_tgt_dtyp(i) = 'CLOB') OR
               (l_src_dtyp(i) = 'LONG RAW' AND l_tgt_dtyp(i) = 'BLOB') THEN
               null; -- long data columns will either be deleted or converted to lob
            ELSE
                -- target has column that has a different data type in source
                l_abort := 'Y';
            END IF;
        ELSIF (l_src_dlen(i) > l_tgt_dlen(i)) THEN
            -- target has column that is shorter than in source
            l_abort := 'Y';
        END IF;

        -- add differences row
        execute immediate l_plsql
        using p_tgt_table, l_col_list(i),
              l_src_dtyp(i), l_src_dlen(i), l_src_null(i),
              l_tgt_dtyp(i), l_tgt_dlen(i), l_tgt_null(i),
              l_abort;
    END LOOP;

  END;

  PROCEDURE set_key_cols (
    p_tgt_owner 	IN     VARCHAR2,
    p_tgt_table 	IN     VARCHAR2
  ) IS
  -- local procedure set_key_cols
  -- will update entries in p_tgt_owner.STRM_TAB_CONTROL with KEY_COLUMNS value
    
    l_plsql		varchar2(4000); 
    l_tgt_owner		varchar2(30) := mis_gen_pkg.strip_input(p_tgt_owner,30);
    l_key_column_list 	mis_gen_pkg.object_list;
    l_key_column_str	varchar2(400) := '';
    
  BEGIN
    
    -- get primary key columns
    l_plsql := 'select acc.column_name ' ||
                 'from all_cons_columns acc, all_constraints ac ' ||
                'where ac.constraint_type = ''P'' ' ||
                  'and ac.owner = :owner ' ||
                  'and ac.table_name = :table_name ' ||
                  'and acc.constraint_name = ac.constraint_name ' ||
                  'and acc.table_name = ac.table_name ' ||
                  'and acc.owner = ac.owner ' ||
                  'and acc.column_name != ''MIS_LOAD_ID''';  
    execute immediate l_plsql bulk collect into l_key_column_list
    using l_tgt_owner, p_tgt_table;
    
    IF l_key_column_list.count > 0 THEN
        -- primary key info defined
        l_key_column_str := mis_gen_pkg.object_list_to_comma(l_key_column_list);
    END IF;
        
    l_plsql := 'update ' || l_tgt_owner || '.STRM_TAB_CONTROL ' ||
                  'set KEY_COLUMNS = :key_columns ' ||
                'where tgt_table = :tgt_table';
    execute immediate l_plsql
    using l_key_column_str, p_tgt_table;

  END;


  PROCEDURE add_tab_control (
    p_src_db 		IN     VARCHAR2,
    p_src_owner 	IN     VARCHAR2,
    p_src_table 	IN     VARCHAR2,
    p_tgt_owner 	IN     VARCHAR2,
    p_tgt_table 	IN     VARCHAR2,
    p_keep_dups 	IN     CHAR DEFAULT 'N',
    p_proc_flags 	IN     VARCHAR2 DEFAULT null
  ) IS
  -- packaged procedure add_tab_control
  -- will insert/overwrite an entry in p_tgt_owner.STRM_TAB_CONTROL

    l_plsql 	varchar2(2000) := ''; 
    l_src_db	varchar2(128) := mis_gen_pkg.strip_input(p_src_db,128);
    l_src_owner	varchar2(30) := mis_gen_pkg.strip_input(p_src_owner,30);
    l_src_table	varchar2(30) := mis_gen_pkg.strip_input(p_src_table,30);
    l_tgt_owner	varchar2(30) := mis_gen_pkg.strip_input(p_tgt_owner,30);
    l_tgt_table	varchar2(30) := mis_gen_pkg.strip_input(p_tgt_table,30);
    l_proc_flag varchar2(30) := replace(mis_gen_pkg.strip_input(p_proc_flags,30),',',' ');
    l_tab_seq 	number; 

  BEGIN

    -- remove old STRM_TAB_CONTROL entry (if any)
    l_plsql := 'delete from ' || l_tgt_owner || '.STRM_TAB_CONTROL ' ||
                'where tgt_table = :tgt_table';
    execute immediate l_plsql
    using l_tgt_table;

    -- get table sequence value
    l_plsql := 'select ' || l_tgt_owner || '.STRM_TAB_CONTROL_SEQ.NEXTVAL from sys.dual';
    execute immediate l_plsql into l_tab_seq;

    -- add new STRM_TAB_CONTROL entry
    l_plsql := 'insert into ' || l_tgt_owner || '.STRM_TAB_CONTROL ' ||
               '(SRC_DB, SRC_OWNER, SRC_TABLE, TGT_TABLE, KEEP_DUPS, PROC_FLAGS, TAB_SEQ) VALUES ' ||
               '(:src_db, :src_owner, :src_table, :tgt_table, :keep_dups, :proc_flags, :tab_seq)';
    execute immediate l_plsql
    using l_src_db, l_src_owner, l_src_table, l_tgt_table, p_keep_dups, l_proc_flag, l_tab_seq;

    -- update STRM_TAB_CONTROL entry with KEY_COLUMNS
    set_key_cols (l_tgt_owner, l_tgt_table);

    -- add STRM_COL_DELETIONS entries
    set_col_deletions (l_src_db, l_src_owner, l_src_table, l_tgt_owner, l_tgt_table, l_proc_flag);

    -- add STRM_COL_DIFFERENCES entries
    set_col_differences (l_src_db, l_src_owner, l_src_table, l_tgt_owner, l_tgt_table);

  END;


  FUNCTION target_table_exists (
    p_tgt_owner 	IN     VARCHAR2,
    p_tgt_table 	IN     VARCHAR2
  ) RETURN BOOLEAN
  IS
  -- local function target_table_exists
  -- returns TRUE if the specified table exists

    l_plsql 		varchar2(2000);
    l_tgt_table 	VARCHAR2(30);

  BEGIN

    l_plsql := 'select table_name ' ||
                 'from all_tables ' ||
                'where owner = upper(:owner) ' ||
                  'and table_name = upper(:table_name)';

    execute immediate l_plsql
    into l_tgt_table
    using p_tgt_owner, p_tgt_table;

    RETURN TRUE;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN FALSE;
  END;

  FUNCTION source_table_exists (
    p_src_db 		IN     VARCHAR2,
    p_src_owner 	IN     VARCHAR2,
    p_src_table 	IN     VARCHAR2
  ) RETURN BOOLEAN
  IS
  -- local function source_table_exists
  -- returns TRUE if the specified table exists

    l_plsql 		varchar2(2000);
    l_src_table 	VARCHAR2(30);
    l_src_db	varchar2(128) := mis_gen_pkg.strip_input(p_src_db,128);

  BEGIN

    l_plsql := 'select table_name ' ||
                 'from all_tables@' || l_src_db || ' ' ||
                'where owner = upper(:owner) ' ||
                  'and table_name = upper(:table_name)';

    execute immediate l_plsql
    into l_src_table
    using p_src_owner, p_src_table;

    RETURN TRUE;

  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN FALSE;
  END;


  PROCEDURE refresh_col_controls (
    p_tgt_owner 	IN     VARCHAR2,
    p_tgt_table 	IN     VARCHAR2 DEFAULT NULL
  ) IS
  -- packaged procedure refresh_col_deletions
  -- will overwrite entries in p_tgt_owner.STRM_COL_DELETIONS
  -- and p_tgt_owner.STRM_COL_DIFFERENCES
  -- and update p_tgt_owner.STRM_TAB_CONTROL.KEY_COLUMNS

    l_plsql 	varchar2(2000); 
    l_tgt_owner	varchar2(30) := mis_gen_pkg.strip_input(p_tgt_owner,30);

    l_src_db_name_list	mis_gen_pkg.db_name_list;
    l_src_owner_list	mis_gen_pkg.owner_list;
    l_src_table_list	mis_gen_pkg.object_list;
    l_tgt_table_list	mis_gen_pkg.object_list;
    l_proc_flag_list	mis_gen_pkg.object_list;
  BEGIN

    l_plsql := 'select src_db, src_owner, src_table, tgt_table, proc_flags ' ||
                 'from ' || l_tgt_owner || '.STRM_TAB_CONTROL';

    IF p_tgt_table IS NULL THEN
        execute immediate l_plsql
        bulk collect into l_src_db_name_list, l_src_owner_list, l_src_table_list,
                          l_tgt_table_list, l_proc_flag_list;
    ELSE
        l_plsql := l_plsql || ' where tgt_table = :tgt_table';
        execute immediate l_plsql
        bulk collect into l_src_db_name_list, l_src_owner_list, l_src_table_list,
                          l_tgt_table_list, l_proc_flag_list
        using p_tgt_table;
    END IF;

    FOR i in 1..l_src_owner_list.count
    LOOP
        set_key_cols (l_tgt_owner, l_tgt_table_list(i));
        set_col_deletions (l_src_db_name_list(i), l_src_owner_list(i),
                           l_src_table_list(i), l_tgt_owner, l_tgt_table_list(i), l_proc_flag_list(i));
        set_col_differences (l_src_db_name_list(i), l_src_owner_list(i),
                           l_src_table_list(i), l_tgt_owner, l_tgt_table_list(i));
    END LOOP;

    mis_gen_pkg.log_strm_debug (l_tgt_owner, 'refresh_col_controls',
                    'Column deletions and differences reset for ' || l_src_owner_list.count ||
                    ' tables (' || nvl(p_tgt_table,'%') || ').');

  END;


  PROCEDURE update_tab_stats (
    p_tgt_owner 	IN     VARCHAR2,
    p_tgt_table 	IN     VARCHAR2
  ) IS
  -- local procedure update_tab_stats
  -- will gather statistics for a table (if out of date)

    l_plsql 	varchar2(2000); 
    l_tgt_owner	varchar2(30) := mis_gen_pkg.strip_input(p_tgt_owner,30);
    l_tgt_table	varchar2(30) := mis_gen_pkg.strip_input(p_tgt_table,30);

    l_gather 		BOOLEAN := FALSE;
    l_num_rows 		number;
    l_last_analyzed 	DATE;
    l_row_count 	number := NULL;
    l_stats_aged 	number := mis_gen_pkg.g_stats_max_days;
    l_stats_new 	number := (mis_gen_pkg.g_stats_min_mins/1440);
    l_stats_pct 	number := mis_gen_pkg.g_stats_pct_tolerance;
    l_stats_low_count 	number := mis_gen_pkg.g_stats_low_count;

  BEGIN

    -- determine current stored details from ALL_TABLES
    l_plsql := 'select nvl(at.num_rows,0), ' ||
                      'nvl(at.last_analyzed,sysdate-:stats_age-1) ' ||
                 'from all_tables at ' ||
                'where at.owner = upper(:tgt_owner) ' ||
                  'and at.table_name = upper(:tgt_table)';

    execute immediate l_plsql into l_num_rows, l_last_analyzed
    using l_stats_aged, l_tgt_owner, l_tgt_table;

    -- determine if it is worth gathering statistics
    CASE
        WHEN l_num_rows <= l_stats_low_count THEN l_gather := TRUE;
        WHEN l_last_analyzed >= (sysdate-l_stats_new) THEN l_gather := FALSE;
        WHEN l_last_analyzed <= (sysdate-l_stats_aged) THEN l_gather := TRUE;
        ELSE
            l_plsql := 'select count(1) ' ||
                         'from ' || l_tgt_owner || '.' || l_tgt_table;
            execute immediate l_plsql into l_row_count;
            IF l_row_count NOT BETWEEN (l_num_rows*(1-l_stats_pct/100))
                                   AND (l_num_rows*(1+l_stats_pct/100)) THEN
                l_gather := TRUE;
            END IF;
    END CASE;

    IF l_gather THEN
        -- update stored statistics for table
        IF l_row_count IS NULL THEN
            mis_gen_pkg.log_strm_debug (l_tgt_owner, 'update_tab_stats',
                            'Refreshing statistics for ' || l_tgt_table ||
                            ' (' || l_num_rows|| ' rows - presumed).', -1);
        ELSE
            mis_gen_pkg.log_strm_debug (l_tgt_owner, 'update_tab_stats',
                            'Refreshing statistics for ' || l_tgt_table ||
                            ' (' || l_row_count || ' rows - actual).', -1);
        END IF;
        DBMS_STATS.GATHER_TABLE_STATS (l_tgt_owner, l_tgt_table,
            estimate_percent => DBMS_STATS.AUTO_SAMPLE_SIZE,
            method_opt => 'FOR ALL COLUMNS SIZE AUTO',
            degree => DBMS_STATS.AUTO_DEGREE,
            granularity => 'ALL',
            cascade => TRUE,
            no_invalidate => DBMS_STATS.AUTO_INVALIDATE);
    END IF;

  EXCEPTION

    WHEN OTHERS THEN
        mis_gen_pkg.log_strm_error (l_tgt_owner, 'update_tab_stats',
                        p_tgt_table => l_tgt_table,
                        p_err_code => SQLCODE, p_text => SQLERRM ||' Error line :' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;

  END;


  PROCEDURE check_table_existence (
    p_staging_owner 	IN     VARCHAR2
  ) IS
  -- packaged procedure check_table_existence
  -- will raise an exception if tables listed in STRM_TAB_CONTROL
  -- do not exist in source or target schemas (or if STRM_TAB_CONTROL is empty)
  -- if tables exist will update target table statistics if indicated 

    l_plsql 		varchar2(2000); 
    l_staging_owner	varchar2(30) := mis_gen_pkg.strip_input(p_staging_owner,30);

    l_src_db_name_list	mis_gen_pkg.db_name_list;
    l_src_owner_list	mis_gen_pkg.owner_list;
    l_src_table_list	mis_gen_pkg.object_list;
    l_tgt_table_list	mis_gen_pkg.object_list;
    l_proc_flag_list	mis_gen_pkg.object_list;
    l_error 		BOOLEAN := FALSE;

  BEGIN

    l_plsql := 'select src_db, src_owner, src_table, tgt_table, proc_flags ' ||
                 'from ' || l_staging_owner || '.STRM_TAB_CONTROL';

    execute immediate l_plsql
    bulk collect into l_src_db_name_list, l_src_owner_list, l_src_table_list,
                      l_tgt_table_list, l_proc_flag_list;

    IF l_src_owner_list.count = 0 THEN
        RAISE_APPLICATION_ERROR(mis_gen_pkg.g_mis_streams_exception,'STRM_TAB_CONTROL is empty.');
    END IF;

    FOR i in 1..l_src_owner_list.count
    LOOP
        IF NOT target_table_exists(l_staging_owner, l_tgt_table_list(i)) THEN
            l_error := TRUE;
            mis_gen_pkg.log_strm_message (l_staging_owner, 'check_table_existence',
                    'Target table ' || l_tgt_table_list(i) || ' does not exist.');
        ELSIF NOT source_table_exists
                    (l_src_db_name_list(i), l_src_owner_list(i), l_src_table_list(i)) THEN
            l_error := TRUE;
            mis_gen_pkg.log_strm_message (l_staging_owner, 'check_table_existence',
                    'Source table ' || l_src_owner_list(i) || '.' || l_src_table_list(i) || '@' ||
                    l_src_db_name_list(i) || ' does not exist.');
        ELSE
            -- source and target tables exist
            -- update target table statistics if required
            IF (instr(l_proc_flag_list(i), 'STATS') > 0) THEN
                update_tab_stats(l_staging_owner, l_tgt_table_list(i));
            END IF;
        END IF;
    END LOOP;

    IF l_error = TRUE THEN
        RAISE_APPLICATION_ERROR(mis_gen_pkg.g_mis_streams_table_exception,'Table does not exist.');
    END IF;

  END;


  PROCEDURE check_differences (
    p_staging_owner 	IN     VARCHAR2
  ) IS
  -- packaged procedure check_differences
  -- will raise an exception if critical column type differences exist
  -- between source and target for any staging tables
    l_plsql		varchar2(2000);
    l_staging_owner	varchar2(30) := mis_gen_pkg.strip_input(p_staging_owner,30);
    l_abort_cnt 	NUMBER;
  BEGIN
    -- check table differences information
    l_plsql := 'select count(abort_flag) ' ||
                 'from ' || l_staging_owner || '.' || 'STRM_COL_DIFFERENCES';  
    execute immediate l_plsql into l_abort_cnt;

    IF l_abort_cnt > 0 THEN
        mis_gen_pkg.log_strm_message(l_staging_owner, 'check_differences',
                         'ERRORS DETECTED - '||l_abort_cnt||' target columns have wrong data types.');
        RAISE_APPLICATION_ERROR(mis_gen_pkg.g_mis_streams_data_exception,'Columns have wrong data types.');
    END IF;
  END;  

  PROCEDURE refresh_apply_keys (
    p_staging_owner 	IN varchar2,
    p_tgt_table 	IN     VARCHAR2 DEFAULT NULL
  ) IS
  -- packaged procedure refresh_apply_keys
  -- will select not to compare old column values for staging tables during apply.

    l_plsql 		varchar2(2000);
    l_staging_owner	varchar2(30) := mis_gen_pkg.strip_input(p_staging_owner,30);
    l_tgt_table_list	mis_gen_pkg.object_list;

  BEGIN

    l_plsql := 'select tgt_table ' ||
                 'from ' || l_staging_owner || '.STRM_TAB_CONTROL';

    IF p_tgt_table IS NULL THEN
        execute immediate l_plsql
        bulk collect into l_tgt_table_list;
    ELSE
        l_plsql := l_plsql || ' where tgt_table = :tgt_table';
        execute immediate l_plsql
        bulk collect into l_tgt_table_list
        using p_tgt_table;
    END IF;

    FOR i in 1..l_tgt_table_list.count
    LOOP
        -- only want to compare on key values
        DBMS_APPLY_ADM.COMPARE_OLD_VALUES(
            object_name => l_staging_owner || '.' || l_tgt_table_list(i),
            column_list => '*',
            operation => '*',
            compare => FALSE);
    END LOOP;

  EXCEPTION

    WHEN OTHERS THEN
        mis_gen_pkg.log_strm_error (l_staging_owner, 'refresh_apply_keys',
                        p_err_code => SQLCODE, p_text => SQLERRM ||' Error line :' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
        RAISE;

  END;


END MIS_TAB_CTRL_PKG;
/

show errors
