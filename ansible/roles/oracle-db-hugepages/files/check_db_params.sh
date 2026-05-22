#!/bin/bash
#
# Check Oracle memory parameters required for HugePage support.
# This script is read-only: it makes no changes to the database.
#
# Outputs one line per parameter violation, including the exact ALTER SYSTEM
# command required to correct it.  Exits non-zero only if sqlplus itself fails.
#

. ~/.bash_profile
export PATH=$PATH:/usr/local/bin
export ORAENV_ASK=NO
export ORACLE_SID=${TARGET_DB_NAME}
. oraenv -s

sqlplus -s / as sysdba <<EOSQL
SET PAGES 0
SET FEEDBACK OFF
SET HEADING OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT FAILURE

DECLARE
  v_db                VARCHAR2(100);
  v_memory_target     VARCHAR2(100);
  v_memory_max_target VARCHAR2(100);
  v_sga_target        VARCHAR2(100);
  v_sga_max_size      VARCHAR2(100);
  v_use_large_pages   VARCHAR2(100);
BEGIN
  SELECT instance_name     INTO v_db                FROM v\$instance;
  SELECT NVL(value, '0')   INTO v_memory_target     FROM v\$parameter WHERE name = 'memory_target';
  SELECT NVL(value, '0')   INTO v_memory_max_target FROM v\$parameter WHERE name = 'memory_max_target';
  SELECT NVL(value, '0')   INTO v_sga_target        FROM v\$parameter WHERE name = 'sga_target';
  SELECT NVL(value, '0')   INTO v_sga_max_size      FROM v\$parameter WHERE name = 'sga_max_size';
  SELECT NVL(value,'FALSE') INTO v_use_large_pages   FROM v\$parameter WHERE name = 'use_large_pages';

  IF TO_NUMBER(v_memory_target) != 0 THEN
    DBMS_OUTPUT.PUT_LINE(
      '[' || v_db || '] memory_target = ' || v_memory_target || ' bytes (must be 0).'
      || ' Fix: ALTER SYSTEM SET memory_target=0 SCOPE=SPFILE;');
  END IF;

  IF TO_NUMBER(v_memory_max_target) != 0 THEN
    DBMS_OUTPUT.PUT_LINE(
      '[' || v_db || '] memory_max_target = ' || v_memory_max_target || ' bytes (must be 0).'
      || ' Fix: ALTER SYSTEM SET memory_max_target=0 SCOPE=SPFILE;');
  END IF;

  IF TO_NUMBER(v_sga_target) = 0 THEN
    DBMS_OUTPUT.PUT_LINE(
      '[' || v_db || '] sga_target = 0 (must be non-zero).'
      || ' Fix: ALTER SYSTEM SET sga_target=<value> SCOPE=SPFILE;');
  END IF;

  IF TO_NUMBER(v_sga_max_size) = 0 THEN
    DBMS_OUTPUT.PUT_LINE(
      '[' || v_db || '] sga_max_size = 0 (must be non-zero).'
      || ' Fix: ALTER SYSTEM SET sga_max_size=<value> SCOPE=SPFILE;');
  END IF;

  IF UPPER(v_use_large_pages) NOT IN ('TRUE', 'ONLY') THEN
    DBMS_OUTPUT.PUT_LINE(
      '[' || v_db || '] use_large_pages = ' || v_use_large_pages || ' (must be TRUE or ONLY).'
      || ' Fix: ALTER SYSTEM SET use_large_pages=true SCOPE=SPFILE; or ALTER SYSTEM SET use_large_pages=only SCOPE=SPFILE;');
  END IF;
END;
/
EXIT
EOSQL
