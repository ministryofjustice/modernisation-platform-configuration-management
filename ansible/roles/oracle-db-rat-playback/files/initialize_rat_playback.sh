#!/bin/bash
. ~/.bash_profile

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <directory_name> <directory_path> <replay_name>" >&2
  exit 1
fi

replay_directory_name="$1"
replay_directory_path="$2"
replay_name="$3"
target_db_name="${TARGET_DB_NAME:-${ORACLE_SID:-}}"

if [[ -z "${target_db_name}" ]]; then
  echo "Set TARGET_DB_NAME or ORACLE_SID before running this script." >&2
  exit 1
fi

echo "Replay directory name: ${replay_directory_name}"
echo "Replay directory path: ${replay_directory_path}"
echo "Replay name: ${replay_name}"
echo "Target database name: ${target_db_name}"

export PATH="$PATH:/usr/local/bin"
export ORAENV_ASK=NO
export ORACLE_SID="${target_db_name}"
. oraenv -s

sqlplus -s / as sysdba <<EOF
whenever sqlerror exit failure
set serveroutput on
declare
begin
  begin
    execute immediate 'create directory $replay_directory_name as ''$replay_directory_path''';
  exception
    when others then
      if sqlcode != -955 then
        raise;
      end if;
  end;

  DBMS_WORKLOAD_REPLAY.PROCESS_CAPTURE(
    capture_dir => '$replay_directory_name');
  DBMS_WORKLOAD_REPLAY.INITIALIZE_REPLAY(
    replay_name => '$replay_name',
    replay_dir  => '$replay_directory_name');
end;
/
exit
EOF