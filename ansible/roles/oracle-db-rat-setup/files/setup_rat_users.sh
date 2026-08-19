#!/bin/bash
. ~/.bash_profile

set -euo pipefail

target_db_name="${TARGET_DB_NAME:-${ORACLE_SID:-}}"
rat_secret_id="${RAT_SECRET_ID:-}"
aws_region="${AWS_REGION:-}"

if [[ -z "${target_db_name}" ]]; then
  echo "Set TARGET_DB_NAME or ORACLE_SID before running this script." >&2
  exit 1
fi

if [[ -z "${rat_secret_id}" || -z "${aws_region}" ]]; then
  echo "Set RAT_SECRET_ID and AWS_REGION before running this script." >&2
  exit 1
fi

export PATH="$PATH:/usr/local/bin"
rat_capture_password_base64="$(aws secretsmanager get-secret-value \
  --secret-id "${rat_secret_id}" \
  --region "${aws_region}" \
  --query SecretString \
  --output text | jq -er '.rat_capture' | base64 | tr -d '\n')"
rat_replay_password_base64="$(aws secretsmanager get-secret-value \
  --secret-id "${rat_secret_id}" \
  --region "${aws_region}" \
  --query SecretString \
  --output text | jq -er '.rat_replay' | base64 | tr -d '\n')"

if [[ -z "${rat_capture_password_base64}" || -z "${rat_replay_password_base64}" ]]; then
  echo "RAT_CAPTURE or RAT_REPLAY password is empty in secret ${rat_secret_id}." >&2
  exit 1
fi

export ORAENV_ASK=NO
export ORACLE_SID="${target_db_name}"
. oraenv -s

sqlplus -s / as sysdba <<EOF
whenever sqlerror exit failure
set serverout on
declare
  type privileges_t is table of varchar2(100);
  common_privileges privileges_t := privileges_t(
    'create session',
    'create any directory',
    'select_catalog_role');

  function decode_password(password_base64 varchar2) return varchar2 is
  begin
    return utl_raw.cast_to_varchar2(
      utl_encode.base64_decode(utl_raw.cast_to_raw(password_base64)));
  end;

  procedure create_or_unlock_user(user_name varchar2, user_password varchar2) is
  begin
    execute immediate 'create user ' || user_name || ' identified by ' || user_password;
  exception
    when others then
      if sqlcode = -1920 then
        execute immediate 'alter user ' || user_name || ' identified by ' || user_password || ' account unlock';
      else
        raise;
      end if;
  end;

  procedure grant_common_privileges(user_name varchar2) is
  begin
    for privilege_index in 1 .. common_privileges.count loop
      execute immediate 'grant ' || common_privileges(privilege_index) || ' to ' || user_name;
    end loop;
  end;
begin
  create_or_unlock_user('RAT_CAPTURE', decode_password('${rat_capture_password_base64}'));
  grant_common_privileges('RAT_CAPTURE');
  execute immediate 'grant execute on DBMS_WORKLOAD_CAPTURE to RAT_CAPTURE';

  create_or_unlock_user('RAT_REPLAY', decode_password('${rat_replay_password_base64}'));
  grant_common_privileges('RAT_REPLAY');
  execute immediate 'grant execute on DBMS_WORKLOAD_REPLAY to RAT_REPLAY';
  execute immediate 'grant become user to RAT_REPLAY';

end;
/
exit
EOF