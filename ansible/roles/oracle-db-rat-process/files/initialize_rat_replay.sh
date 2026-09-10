#!/bin/bash
. ~/.bash_profile

set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "Usage: $0 <directory_name> <directory_path> <replay_name> <tns_alias>" >&2
  exit 1
fi

replay_directory_name="$1"
replay_directory_path="$2"
replay_name="$3"
tns_alias="$4"

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
echo "Replay directory path: ${replay_directory_path}"
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

echo "Creating replay directory"
sqlplus -s /nolog <<EOF
whenever sqlerror exit failure
connect RAT_REPLAY/${rat_replay_password}@${tns_alias}
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
end;
/
exit
EOF

echo "Processing capture files"
sqlplus -s /nolog <<EOF
whenever sqlerror exit failure
connect RAT_REPLAY/${rat_replay_password}@${tns_alias}
set serveroutput on
declare
begin
  DBMS_WORKLOAD_REPLAY.PROCESS_CAPTURE(
    capture_dir => '$replay_directory_name');
end;
/
exit
EOF

echo "Initialising replay"
sqlplus -s /nolog <<EOF
whenever sqlerror exit failure
connect RAT_REPLAY/${rat_replay_password}@${tns_alias}
set serverout on
declare
begin
  DBMS_WORKLOAD_REPLAY.INITIALIZE_REPLAY(
    replay_name => '$replay_name',
    replay_dir  => '$replay_directory_name');
end;
/
exit
EOF