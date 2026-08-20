#!/bin/bash
. ~/.bash_profile

set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <directory_path> <client_count> <startup_delay_seconds> <tns_alias>" >&2
  exit 1
fi

replay_directory_path="$1"
client_count="$2"
startup_delay_seconds="$3"
tns_alias="$4"
target_db_name="${TARGET_DB_NAME:-${ORACLE_SID:-}}"
rat_secret_id="${RAT_SECRET_ID:-}"
aws_region="${AWS_REGION:-}"

if [[ -z "${target_db_name}" ]]; then
  echo "Set TARGET_DB_NAME or ORACLE_SID before running this script." >&2
  exit 1
fi

if [[ -z "${tns_alias}" ]]; then
  echo "Set tns_alias before running this script." >&2
  exit 1
fi

if [[ -z "${rat_secret_id}" || -z "${aws_region}" ]]; then
  echo "Set RAT_SECRET_ID and AWS_REGION before running this script." >&2
  exit 1
fi

echo "Replay directory path: ${replay_directory_path}"
echo "Target database name: ${target_db_name}"
echo "WRC replay client count: ${client_count}"

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

wrc_connection="RAT_REPLAY/${rat_replay_password}@${tns_alias}"
export ORAENV_ASK=NO
export ORACLE_SID="${target_db_name}"
. oraenv -s

wrc "$wrc_connection" mode=calibrate replaydir="$replay_directory_path"

for client_number in $(seq 1 "$client_count"); do
  log_file="${replay_directory_path}/wrc-replay-${client_number}.log"
  echo "Starting WRC replay client ${client_number}; log: ${log_file}"
  nohup wrc "$wrc_connection" mode=replay replaydir="$replay_directory_path" > "$log_file" 2>&1 &
done

if [[ "$startup_delay_seconds" -gt 0 ]]; then
  echo "Waiting ${startup_delay_seconds} seconds for WRC replay clients to connect"
  sleep "$startup_delay_seconds"
fi