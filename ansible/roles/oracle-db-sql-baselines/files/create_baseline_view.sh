#!/bin/bash
#
# Create a View to access the SQL Plan Baseline data held in the $BASELINE_FILE_NAME JSON file.
#
# NOTE:
#
# Baseline Files may be generated from a source database in the correct format as follows:
#
# (1) 
#     EXEC DBMS_SPM.CREATE_STGTAB_BASELINE('STGTAB', USER);
# (2)
#     DECLARE
#        x number;
#     BEGIN
#        x := DBMS_SPM.PACK_STGTAB_BASELINE('STGTAB', user, sql_handle => 'SQL_55297a64b8f91421' );
#        dbms_output.put_line(to_char(x) || ' plan baselines packed');
#     END;
#     / 
# (3) Export as JSON file (e.g. Using SQL*Developer Export Tool)
#     Manually amend the key "results" to "baseline".
#     There should only be one baseline per file.  The filename should
#     be the name of the baseline. 
#     (Take care if the OTHER_XML column is over 4000 characters; you
#      may need to export this separately using JSON_OBECT(... AS CLOB))

BASELINE_FILE_NAME=$1

. ~/.bash_profile
export PATH=$PATH:/usr/local/bin
. oraenv <<< ${TARGET_DB_NAME}

sqlplus -s / as sysdba<<EOSQL
-- Create baseline view
WHENEVER SQLERROR EXIT FAILURE
CREATE OR REPLACE VIEW ${DBA_OPS_SCHEMA}.sql_plan_baseline_data
AS
SELECT *
FROM JSON_TABLE (
       BFileName('SQL_PLAN_BASELINE_DATA_DIR', '${BASELINE_FILE_NAME}')
       , '$.baseline[0].items[*]'
       COLUMNS (
           version NUMBER PATH '$.version',
           signature NUMBER PATH '$.signature',
           sql_handle VARCHAR2(30) PATH '$.sql_handle',
           obj_name VARCHAR2(128) PATH '$.obj_name',
           obj_type VARCHAR2(30) PATH '$.obj_type',
           plan_id NUMBER PATH '$.plan_id',
           sql_text CLOB PATH '$.sql_text',
           creator VARCHAR2(128) PATH '$.creator',
           origin VARCHAR2(30) PATH '$.origin',
           description VARCHAR2(500) PATH '$.description',
           db_version VARCHAR2(64) PATH '$.db_version',
           created TIMESTAMP(6) PATH '$.created',
           last_modified TIMESTAMP(6) PATH '$.last_modified',
           last_executed TIMESTAMP(6) PATH '$.last_executed',
           last_verified TIMESTAMP(6) PATH '$.last_verified',
           status NUMBER PATH '$.status',
           optimizer_cost NUMBER PATH '$.optimizer_cost',
           module VARCHAR2(64) PATH '$.module',
           action VARCHAR2(64) PATH '$.action',
           executions NUMBER PATH '$.executions',
           elapsed_time NUMBER PATH '$.elapsed_time',
           cpu_time NUMBER PATH '$.cpu_time',
           buffer_gets NUMBER PATH '$.buffer_gets',
           disk_reads NUMBER PATH '$.disk_reads',
           direct_writes NUMBER PATH '$.direct_writes',
           rows_processed NUMBER PATH '$.rows_processed',
           fetches NUMBER PATH '$.fetches',
           end_of_fetch_count NUMBER PATH '$.end_of_fetch_count',
           category VARCHAR2(128) PATH '$.category',
           sqlflags NUMBER PATH '$.sqlflags',
           task_id NUMBER PATH '$.task_id',
           task_exec_name VARCHAR2(128) PATH '$.task_exec_name',
           task_obj_id NUMBER PATH '$.task_obj_id',
           task_fnd_id NUMBER PATH '$.task_fnd_id',
           task_rec_id NUMBER PATH '$.task_rec_id',
           inuse_features NUMBER PATH '$.inuse_features',
           parse_cpu_time NUMBER PATH '$.parse_cpu_time',
           priority NUMBER PATH '$.priority',
           optimizer_env VARCHAR2(2000) PATH '$.optimizer_env',
           bind_data VARCHAR2(2000) PATH '$.bind_data',
           parsing_schema_name VARCHAR2(128) PATH '$.parsing_schema_name',
           comp_data CLOB PATH '$.comp_data',
           statement_id VARCHAR2(30) PATH '$.statement_id',
           xpl_plan_id NUMBER PATH '$.xpl_plan_id',
           timestamp DATE PATH '$.timestamp',
           remarks VARCHAR2(4000) PATH '$.remarks',
           operation VARCHAR2(30) PATH '$.operation',
           options VARCHAR2(255) PATH '$.options',
           object_node VARCHAR2(128) PATH '$.object_node',
           object_owner VARCHAR2(128) PATH '$.object_owner',
           object_name VARCHAR2(128) PATH '$.object_name',
           object_alias VARCHAR2(261) PATH '$.object_alias',
           object_instance NUMBER PATH '$.object_instance',
           object_type VARCHAR2(30) PATH '$.object_type',
           optimizer VARCHAR2(255) PATH '$.optimizer',
           search_columns NUMBER PATH '$.search_columns',
           id NUMBER PATH '$.id',
           parent_id NUMBER PATH '$.parent_id',
           depth NUMBER PATH '$.depth',
           position NUMBER PATH '$.position',
           cost NUMBER PATH '$.cost',
           cardinality NUMBER PATH '$.cardinality',
           bytes NUMBER PATH '$.bytes',
           other_tag VARCHAR2(255) PATH '$.other_tag',
           partition_start VARCHAR2(255) PATH '$.partition_start',
           partition_stop VARCHAR2(255) PATH '$.partition_stop',
           partition_id NUMBER PATH '$.partition_id',
           distribution VARCHAR2(30) PATH '$.distribution',
           cpu_cost NUMBER PATH '$.cpu_cost',
           io_cost NUMBER PATH '$.io_cost',
           temp_space NUMBER PATH '$.temp_space',
           access_predicates VARCHAR2(4000) PATH '$.access_predicates',
           filter_predicates VARCHAR2(4000) PATH '$.filter_predicates',
           projection VARCHAR2(4000) PATH '$.projection',
           time NUMBER PATH '$.time',
           qblock_name VARCHAR2(128) PATH '$.qblock_name',
           other_xml CLOB PATH '$.other_xml'
           )
    );


EXIT;
EOSQL