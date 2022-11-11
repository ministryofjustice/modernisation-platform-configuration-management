#!/bin/bash
PROFILE=$1
SSM_PATH=$2

if [[ -z $PROFILE || -z $SSM_PATH ]]; then
  echo "Usage <profile> <ssm_path>"
  exit 1
fi

ADMIN_USERNAME=$(aws ssm get-parameter --name "${SSM_PATH}/WEBLOGIC_USERNAME" --with-decryption --query Parameter.Value --profile "$PROFILE")
ADMIN_PASSWORD=$(aws ssm get-parameter --name "${SSM_PATH}/WEBLOGIC_PASSWORD" --with-decryption --query Parameter.Value --profile "$PROFILE")
DB_USERNAME=$(aws ssm get-parameter --name "${SSM_PATH}/DB_USERNAME" --with-decryption --query Parameter.Value --profile "$PROFILE")
DB_PASSWORD=$(aws ssm get-parameter --name "${SSM_PATH}/DB_PASSWORD" --with-decryption --query Parameter.Value --profile "$PROFILE")

echo ADMIN_USERNAME="$ADMIN_USERNAME"
echo ADMIN_PASSWORD="$ADMIN_PASSWORD"
echo DB_USERNAME="$DB_USERNAME"
echo DB_PASSWORD="$DB_PASSWORD"
