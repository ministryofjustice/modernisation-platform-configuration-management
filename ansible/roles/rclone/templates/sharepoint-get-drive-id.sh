#!/bin/bash
set -e

if [[ -z $APP_REGISTRATION_SECRET_ID ]]; then
  echo "Please set APP_REGISTRATION_SECRET_ID to name of secret containing App Registration credentials" >&2
  exit 1
fi

if [[ -z $SITE_URL_NAME && -z $SITE_ID ]]; then
  echo "Please set either SITE_URL_NAME or SITE_ID to the URLName or Id of the sharepoint site" >&2
  exit 1
fi

echo "# Getting $APP_REGISTRATION_SECRET_ID secret" >&2
APP_REG_SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "$APP_REGISTRATION_SECRET_ID" --query SecretString --output text)

echo "# Extracting client id, secret and tenant_id" >&2
CLIENT_ID=$(jq -r .client_id <<< "$APP_REG_SECRET_VALUE")
CLIENT_SECRET=$(jq -r .client_secret <<< "$APP_REG_SECRET_VALUE")
TENANT_ID=$(jq -r .tenant_id <<< "$APP_REG_SECRET_VALUE")

echo "# Getting OAuth2 Token for client ID $CLIENT_ID from https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token" >&2
OAUTH2_TOKEN=$(curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=$CLIENT_ID" \
  -d "scope=https://graph.microsoft.com/.default" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "grant_type=client_credentials" \
  "https://login.microsoftonline.com/$TENANT_ID/oauth2/v2.0/token")

echo "# Extracting OAuth2 Access Token" >&2
ACCESS_TOKEN=$(echo "$OAUTH2_TOKEN" | jq -r '.access_token')

if [[ -z $SITE_ID ]]; then
  echo "# Getting Site Info from https://graph.microsoft.com/v1.0/sites/justiceuk.sharepoint.com:/sites/$SITE_URL_NAME" >&2
  SITE=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" \
    "https://graph.microsoft.com/v1.0/sites/justiceuk.sharepoint.com:/sites/$SITE_URL_NAME")

  echo "# Extracting Site Id for $SITE_URL_NAME" >&2
  SITE_ID=$(jq -r '.id' <<< "$SITE")
  echo "SITE_ID=$SITE_ID"
fi

echo "# Getting Drive Info from https://graph.microsoft.com/v1.0/sites/$SITE_ID/drives" >&2
DRIVES=$(curl -s -H "Authorization: Bearer $ACCESS_TOKEN" "https://graph.microsoft.com/v1.0/sites/$SITE_ID/drives")

if [[ -z $DRIVE_NAME ]]; then
  echo "# Extracting Drive Names" >&2
  DRIVE_NAMES=$(jq -r '[.value[].name] | join("|")' <<< "$DRIVES")
  echo "DRIVE_NAMES=$DRIVE_NAMES"
  jq -r '.value[] | "\(.name)=\(.id)"' <<< "$DRIVES"
else
  echo "# Extracting $DRIVE_NAME drive id" >&2
  DRIVE_ID=$(jq -r '.value[] | select(.name == "'"$DRIVE_NAME"'").id' <<< "$DRIVES")
  echo "DRIVE_NAME=$DRIVE_ID"
fi
