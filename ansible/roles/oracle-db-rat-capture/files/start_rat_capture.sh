#!/bin/bash
. ~/.bash_profile

set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <directory_name> <directory_path> <capture_name> [schema ...]" >&2
  echo "Provide schemas as additional arguments or set RAT_CAPTURE_SCHEMAS as a comma-separated list." >&2
  exit 1
fi

capture_directory_name="$1"
capture_directory_path="$2"
capture_name="$3"
shift 3

if [[ $# -gt 0 ]]; then
  schemas=("$@")
elif [[ -n "${RAT_CAPTURE_SCHEMAS:-}" ]]; then
  IFS=',' read -r -a schemas <<< "${RAT_CAPTURE_SCHEMAS}"
else
  echo "No schemas supplied. Pass them as arguments or set RAT_CAPTURE_SCHEMAS." >&2
  exit 1
fi

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
rat_capture_password="$(aws secretsmanager get-secret-value \
  --secret-id "${rat_secret_id}" \
  --region "${aws_region}" \
  --query SecretString \
  --output text | jq -er '.rat_capture')"

if [[ -z "${rat_capture_password}" ]]; then
  echo "RAT_CAPTURE password is empty in secret ${rat_secret_id}." >&2
  exit 1
fi

rat_capture_password="${rat_capture_password//\"/\"\"}"
export ORAENV_ASK=NO
export ORACLE_SID="${target_db_name}"
. oraenv -s

umask 077
sql_file="$(mktemp "${TMPDIR:-/tmp}/start-rat-capture.XXXXXX.sql")"
trap 'rm -f "${sql_file}"' EXIT

{
  cat <<EOF
whenever sqlerror exit failure
connect RAT_CAPTURE/"${rat_capture_password}"
set serveroutput on
declare
begin
  dbms_output.put_line('create directory $capture_directory_name as ''$capture_directory_path''');
  begin
    execute immediate 'create directory $capture_directory_name as ''$capture_directory_path''';
  exception
    when others then
      if sqlcode != -955 then
        raise;
      end if;
  end;

EOF

  index=1
  for schema_name in "${schemas[@]}"; do
    printf "  DBMS_WORKLOAD_CAPTURE.ADD_FILTER(\n"
    printf "    fname      => 'capture_%s',\n" "$index"
    printf "    fattribute => 'USER',\n"
    printf "    fvalue     => '%s');\n" "$schema_name"
    index=$((index + 1))
  done

  cat <<EOF

  DBMS_WORKLOAD_CAPTURE.START_CAPTURE(
    name           => '$capture_name',
    dir            => '$capture_directory_name',
    default_action => 'EXCLUDE');
end;
/
exit
EOF
} > "$sql_file"

sqlplus -s /nolog @"$sql_file"