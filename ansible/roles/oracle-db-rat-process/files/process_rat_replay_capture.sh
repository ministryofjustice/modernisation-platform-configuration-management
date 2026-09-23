#!/bin/bash
. ~/.bash_profile

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <directory_name> <tns_alias>" >&2
  exit 1
fi

replay_directory_name="$1"
tns_alias="$2"

rat_secret_id="${RAT_SECRET_ID:-}"
aws_region="${AWS_REGION:-}"

if [[ -z "${tns_alias}" ]]; then
  echo "Set tns_alias before running this script." >&2
  exit 1
fi

if [[ -z "${rat_secret_id}" || -z "${aws_region}" ]]; then
  echo "Set RAT_SECRET_ID and AWS_REGION before running this script." >&2
  exit 1
fi

echo "Replay directory name: ${replay_directory_name}"
echo "Target database name: ${tns_alias}"

export PATH="$PATH:/usr/local/bin"
rat_replay_password="$(aws secretsmanager get-secret-value \
  --secret-id "${rat_secret_id}" \
  --region "${aws_region}" \
  --query SecretString \
  --output text | jq -er '.rat_replay')"

if [[ -z "${rat_replay_password}" ]]; then
  echo "RAT_REPLAY password is empty in secret ${rat_secret_id}." >&2
  exit 1
fi

echo "Processing capture files"
sqlplus -s /nolog <<EOF
whenever sqlerror exit failure
connect RAT_REPLAY/${rat_replay_password}@${tns_alias}
set serveroutput on
declare
begin
  -- PROCESS_CAPTURE reads the raw capture files from the Oracle directory,
  -- validates and converts them into the replay metadata and workload data
  -- required by a replay. This must happen before a replay can be initialized.
  DBMS_WORKLOAD_REPLAY.PROCESS_CAPTURE(
    capture_dir => '$replay_directory_name');
end;
/
exit
EOF
