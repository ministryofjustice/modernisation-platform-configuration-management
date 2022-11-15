#!/bin/bash
set -e
PROFILE=$1
SSM_PATH=$2 # e.g. #/weblogic/CNOMT1 or /test/dev-weblogic-appserver103

if [[ -z $PROFILE || -z $SSM_PATH ]]; then
  echo "Usage <profile> <ssm path>"
  exit 1
fi

if [[ -z $ADMIN_USERNAME || -z $ADMIN_PASSWORD || -z $DB_USERNAME || -z $DB_PASSWORD ]]; then
  echo "Please set ADMIN_USERNAME etc.. environment variables first"
  echo "Read from a file prior to running script"
  echo "set -a"
  echo ". my-creds"
  echo "set +a"
  exit 1
fi

aws ssm put-parameter --name "${SSM_PATH}/WEBLOGIC_USERNAME" --type "SecureString" --data-type "text" --value "$ADMIN_USERNAME" --profile "$PROFILE"
aws ssm put-parameter --name "${SSM_PATH}/WEBLOGIC_PASSWORD" --type "SecureString" --data-type "text" --value "$ADMIN_PASSWORD" --profile "$PROFILE"
aws ssm put-parameter --name "${SSM_PATH}/DB_USERNAME" --type "SecureString" --data-type "text" --value "$DB_USERNAME" --profile "$PROFILE"
aws ssm put-parameter --name "${SSM_PATH}/DB_PASSWORD" --type "SecureString" --data-type "text" --value "$DB_PASSWORD" --profile "$PROFILE"
