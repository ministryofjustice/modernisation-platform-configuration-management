#!/bin/bash
. ~/.bash_profile

set -euo pipefail

target_db_name="${TARGET_DB_NAME:-${ORACLE_SID:-}}"
if [[ -z "${target_db_name}" ]]; then
  echo "Set TARGET_DB_NAME or ORACLE_SID before running this script." >&2
  exit 1
fi

. ~/.bash_profile
export PATH="$PATH:/usr/local/bin"
export ORAENV_ASK=NO
export ORACLE_SID="${target_db_name}"
. oraenv -s

sqlplus -s / as sysdba <<'EOSQL'
whenever sqlerror exit failure
begin
  DBMS_WORKLOAD_CAPTURE.FINISH_CAPTURE;
end;
/
exit
EOSQL