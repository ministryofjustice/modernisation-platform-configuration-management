#!/bin/bash
. ~/.bash_profile

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <directory_path> <startup_delay_seconds> <tns_alias>" >&2
  exit 1
fi

replay_directory_path="$1"
startup_delay_seconds="$2"
tns_alias="$3"

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

echo "Replay directory path: ${replay_directory_path}"
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

wrc_connection="RAT_REPLAY/${rat_replay_password}@${tns_alias}"

CALIBRATE=$(
wrc "$wrc_connection" mode=calibrate replaydir="$replay_directory_path"
)

echo "---- Calibration Output ----"
echo $CALIBRATE
echo "----------------------------"

client_count=$(grep -oP 'Consider using at least \K[0-9]+' <<< "$CALIBRATE")

echo "Starting $client_count clients"

for client_number in $(seq 1 "$client_count"); do
  log_file="${replay_directory_path}/wrc-replay-${client_number}.log"
  echo "Starting WRC replay client ${client_number}; log: ${log_file}"
  nohup wrc "$wrc_connection" mode=replay replaydir="$replay_directory_path" > "$log_file" 2>&1 &
done

if [[ "$startup_delay_seconds" -gt 0 ]]; then
  echo "Waiting ${startup_delay_seconds} seconds for WRC replay clients to connect"
  sleep "$startup_delay_seconds"
fi