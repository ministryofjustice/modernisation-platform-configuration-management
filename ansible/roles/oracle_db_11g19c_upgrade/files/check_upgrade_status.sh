#!/bin/bash

# Display upgrade status 

sqlplus -s / as sysdba <<EOSQL
WHENEVER SQLERROR EXIT FAILURE
set pages 200
set lines 200

select instance_name from v\$instance;

select * from  v\$timezone_file;

column owner format A30 

select owner, object_name from dba_objects where status = 'INVALID';

COLUMN comp_id    FORMAT A12
COLUMN comp_name  FORMAT A40
COLUMN version    FORMAT A15
COLUMN status     FORMAT A12

column owner format A30 
SELECT comp_id,
       comp_name,
       version,
       status
FROM  dba_registry
ORDER BY comp_name;

select status from v\$block_change_tracking;

EOSQL
