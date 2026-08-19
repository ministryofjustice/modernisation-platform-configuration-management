#!/bin/bash
. ~/.bash_profile

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <synchronization>" >&2
  exit 1
fi

synchronization="$1"

target_db_name="${TARGET_DB_NAME:-${ORACLE_SID:-}}"
if [[ -z "${target_db_name}" ]]; then
  echo "Set TARGET_DB_NAME or ORACLE_SID before running this script." >&2
  exit 1
fi

echo "Synchronization: ${synchronization}"
echo "Target database name: ${target_db_name}"

export PATH="$PATH:/usr/local/bin"
export ORAENV_ASK=NO
export ORACLE_SID="${target_db_name}"
. oraenv -s

sqlplus -s / as sysdba <<EOF
whenever sqlerror exit failure
set serveroutput on
begin
  DBMS_WORKLOAD_REPLAY.PREPARE_REPLAY(
    synchronization => '$synchronization');
  DBMS_WORKLOAD_REPLAY.START_REPLAY;
end;
/
exit
EOF