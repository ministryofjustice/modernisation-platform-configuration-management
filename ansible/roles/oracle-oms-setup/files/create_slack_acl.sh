#!/bin/bash

. ~/.bash_profile
export PATH=$PATH:/usr/local/bin
. oraenv

sqlplus -S /nolog <<EOSQL

WHENEVER SQLERROR EXIT FAILURE;

connect / as sysdba

SET SERVEROUT ON

DECLARE
  v_count NUMBER(1);
BEGIN

  SELECT COUNT(*)
  INTO v_count
  FROM dba_network_acls
  WHERE acl = '/sys/acls/slack.xml';

  -- Create slack acl if it does not exist
  IF v_count = 0
  THEN
    DBMS_NETWORK_ACL_ADMIN.create_acl (
      acl          => 'slack.xml', 
      description  => 'Access to slack api',
      principal    => 'SYSMAN',
      is_grant     => TRUE, 
      privilege    => 'connect',
      start_date   => NUll,
      end_date     => NULL);
    COMMIT;
    DBMS_OUTPUT.put_line('ACL created.');
  END IF;

  -- Add the privilege to resolve 
  DBMS_NETWORK_ACL_ADMIN.add_privilege (
    acl          => 'slack.xml',
    principal    => 'SYSMAN',
    is_grant     => TRUE, 
    privilege    => 'resolve');
  COMMIT;

  -- Add the privilege to resolve 
  DBMS_NETWORK_ACL_ADMIN.add_privilege (
    acl          => 'slack.xml',
    principal    => 'SYSMAN',
    is_grant     => TRUE,
    privilege    => 'connect');
  COMMIT;

  -- Assign slack to acl
  DBMS_NETWORK_ACL_ADMIN.assign_acl (
    acl => 'slack.xml',
    host => '*');
  COMMIT;

END;
/
EXIT
EOSQL