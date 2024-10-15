#!/bin/bash
# Wrapper for logging in and querying biprws endpoint

set -e

BIPRWS='{{ sap_bip_rws_url }}'
AUTH=secEnterprise
USERNAME=Administrator

usage() {
  echo "Usage: $0 <query>"
  echo
  echo "e.g. $0 'SELECT * FROM CI_SYSTEMOBJECTS'"
}

login() {
  local logon
  local token

  logon='{"username": "'$USERNAME'", "password": "'$PASSWORD'", "auth": "'$AUTH'"}'
  token=$(curl -Ss -H "Content-Type: application/json" -H "Accept: application/json" --data "$logon" $BIPRWS/v1/logon/long)
  jq -r ".logontoken" <<< $token
}

cms_query() {
  local query
  local token

  token="$1"
  query_escaped=$(jq -R <<< "$2")
  query='{"query":'$query_escaped'}'
  curl -Ss -H "Content-Type: application/json" -H "Accept: application/json" -H "X-SAP-LogonToken: $token" --data "$query" $BIPRWS/v1/cmsquery
}

if [[ -z $1 ]]; then
  usage >&2
  exit 1
fi

if [[ -z $PASSWORD ]]; then
  echo "Please enter password for $USERNAME: " >&2
  read PASSWORD
fi

token="\"$(login)\""
cms_query "$token" "$1"
