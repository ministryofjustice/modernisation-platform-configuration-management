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

sqlplus -s /nolog <<EOF
whenever sqlerror exit failure
connect RAT_CAPTURE/"${rat_capture_password}"
begin
  DBMS_WORKLOAD_CAPTURE.FINISH_CAPTURE;
end;
/
exit
EOF