#!/bin/bash
. ~/.bash_profile

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <replay_name> <directory_name> <tns_alias>" >&2
  exit 1
fi

replay_name="$1"
replay_directory_name="$2"
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

echo "Replay directory name: ${replay_directory_name}"
echo "Replay name: ${replay_name}"
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

echo "Initialising replay"
sqlplus -s /nolog <<EOF
whenever sqlerror exit failure
connect RAT_REPLAY/${rat_replay_password}@${tns_alias}
set serverout on
declare
begin
  -- INITIALIZE_REPLAY creates the named replay session and associates it with
  -- the directory containing the capture that PROCESS_CAPTURE has converted.
  -- This establishes the replay to be prepared and run; it does not process
  -- the capture files or configure replay synchronization.
  DBMS_WORKLOAD_REPLAY.INITIALIZE_REPLAY(
    replay_name => '$replay_name',
    replay_dir  => '$replay_directory_name');
end;
/
exit
EOF