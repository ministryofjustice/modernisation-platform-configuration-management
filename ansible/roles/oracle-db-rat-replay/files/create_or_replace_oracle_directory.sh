#!/bin/bash
. ~/.bash_profile

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "Usage: $0 <directory_name> <directory_path> <tns_alias>" >&2
  exit 1
fi

directory_name="$1"
directory_path="$2"
tns_alias="$3"

rat_secret_id="${RAT_SECRET_ID:-}"
aws_region="${AWS_REGION:-}"

if [[ ! "${directory_name}" =~ ^[A-Za-z][A-Za-z0-9_\$#]*$ ]]; then
  echo "Invalid Oracle directory object name: ${directory_name}" >&2
  exit 1
fi

if [[ -z "${directory_path}" || -z "${tns_alias}" ]]; then
  echo "Set the directory path and TNS alias before running this script." >&2
  exit 1
fi

if [[ -z "${rat_secret_id}" || -z "${aws_region}" ]]; then
  echo "Set RAT_SECRET_ID and AWS_REGION before running this script." >&2
  exit 1
fi

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

escaped_directory_path="${directory_path//\'/\'\'}"

sqlplus -s /nolog <<EOF
whenever sqlerror exit failure
whenever oserror exit failure
connect RAT_REPLAY/${rat_replay_password}@${tns_alias}
set define off
CREATE OR REPLACE DIRECTORY ${directory_name} AS '${escaped_directory_path}';
exit
EOF