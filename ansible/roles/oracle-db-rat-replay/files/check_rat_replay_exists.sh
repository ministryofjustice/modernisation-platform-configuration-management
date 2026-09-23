#!/bin/bash
. ~/.bash_profile

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <replay_name> <tns_alias>" >&2
  exit 1
fi

replay_name="$1"
tns_alias="$2"

rat_secret_id="${RAT_SECRET_ID:-}"
aws_region="${AWS_REGION:-}"

if [[ -z "${replay_name}" || -z "${tns_alias}" ]]; then
  echo "Set replay_name and tns_alias before running this script." >&2
  exit 1
fi

if [[ -z "${rat_secret_id}" || -z "${aws_region}" ]]; then
  echo "Set RAT_SECRET_ID and AWS_REGION before running this script." >&2
  exit 1
fi

echo "Checking whether replay already exists: ${replay_name}"
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

sqlplus -s /nolog <<EOF
whenever sqlerror exit failure
connect RAT_REPLAY/${rat_replay_password}@${tns_alias}
set serveroutput on
set verify off
set heading off
set feedback off
begin
  -- Check the Oracle workload replay catalogue before initialization so that
  -- INITIALIZE_REPLAY cannot overwrite or conflict with an existing replay.
  -- (Ignore cancelled replays)
  for replay_record in (
    select name
      from dba_workload_replays
     where name = '${replay_name}'
     and status != 'CANCELLED'
  ) loop
    raise_application_error(
      -20001,
      'A workload replay named ${replay_name} already exists.');
  end loop;
end;
/
exit
EOF
