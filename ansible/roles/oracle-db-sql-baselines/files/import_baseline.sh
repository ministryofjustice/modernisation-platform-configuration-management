#!/bin/bash
#
#  Note that importing a pre-existing baseline will not produce an error; it will
#  just overwrite it.
#


. ~/.bash_profile
export PATH=$PATH:/usr/local/bin
. oraenv <<< ${TARGET_DB_NAME}

sqlplus / as sysdba<<EOSQL

SET SERVEROUT ON
WHENEVER SQLERROR EXIT FAILURE
DECLARE
x number;
BEGIN
x := DBMS_SPM.UNPACK_STGTAB_BASELINE('SQL_PLAN_BASELINE_DATA', '${DBA_OPS_SCHEMA}');
DBMS_OUTPUT.put_line(to_char(x) || ' plan baselines unpacked');
END;
/
EOSQL