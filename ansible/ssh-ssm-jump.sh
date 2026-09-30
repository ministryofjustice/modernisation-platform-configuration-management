#!/bin/bash
# Referenced by ansible_ssh_common_args to ssh via a jump server using SSM
set -euo pipefail

JUMP_INSTANCE_ID="$1"
TARGET_HOST="$2"
TARGET_PORT="$3"

if [ -z "$ANSIBLE_PRIVATE_KEY_FILE" ]; then
    echo "ERROR: ANSIBLE_PRIVATE_KEY_FILE is not set" >&2
    exit 1
fi

if [ ! -f "${ANSIBLE_PRIVATE_KEY_FILE}" ]; then
    echo "ERROR: SSH private key does not exist: ${ANSIBLE_PRIVATE_KEY_FILE}" >&2
    exit 1
fi

exec ssh \
  -i "${ANSIBLE_PRIVATE_KEY_FILE}" \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o "ProxyCommand=aws ssm start-session \
      --target ${JUMP_INSTANCE_ID} \
      --document-name AWS-StartSSHSession \
      --parameters portNumber=22 \
      --region ${AWS_REGION:-eu-west-2}" \
  -W "${TARGET_HOST}:${TARGET_PORT}" \
  ec2-user@localhost
