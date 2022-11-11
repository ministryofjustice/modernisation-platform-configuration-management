#!/bin/bash
set -e
PROFILE=$1
DB_NAME=$2

if [[ -z $PROFILE || -z $DB_NAME ]]; then
  echo "Usage <profile> <environment>"
  exit 1
fi

aws ssm delete-parameter --name "/weblogic/${DB_NAME}/WEBLOGIC_USERNAME" --profile "$PROFILE"
aws ssm delete-parameter --name "/weblogic/${DB_NAME}/WEBLOGIC_PASSWORD" --profile "$PROFILE"
aws ssm delete-parameter --name "/weblogic/${DB_NAME}/DB_USERNAME" --profile "$PROFILE"
aws ssm delete-parameter --name "/weblogic/${DB_NAME}/DB_PASSWORD" --profile "$PROFILE"
