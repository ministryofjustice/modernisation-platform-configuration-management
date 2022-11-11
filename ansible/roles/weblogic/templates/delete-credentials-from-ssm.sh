#!/bin/bash
set -e
PROFILE=$1
SSM_PATH=$2

if [[ -z $PROFILE || -z $SSM_PATH ]]; then
  echo "Usage <profile> <ssm_path>"
  exit 1
fi

aws ssm delete-parameter --name "${SSM_PATH}/WEBLOGIC_USERNAME" --profile "$PROFILE"
aws ssm delete-parameter --name "${SSM_PATH}/WEBLOGIC_PASSWORD" --profile "$PROFILE"
aws ssm delete-parameter --name "${SSM_PATH}/DB_USERNAME" --profile "$PROFILE"
aws ssm delete-parameter --name "${SSM_PATH}/DB_PASSWORD" --profile "$PROFILE"
