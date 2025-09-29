#!/bin/bash
# Wrapper for logging in and querying biprws endpoint

set -e

BIPRWS='{{ sap_bip_rws_url }}'
AUTH=secEnterprise
USERNAME=Administrator
DEBUG=${DEBUG:-0}
BIPRWS_LOGON_TOKEN=

# Always logout of biprws on exit
trap '[[ -n $BIPRWS_LOGON_TOKEN ]] && curl -Ss -m 5 -H "Content-Type: application/json" -H "Accept: application/json" -H "X-SAP-LogonToken: $BIPRWS_LOGON_TOKEN" --data "" "$BIPRWS/v1/logoff"' EXIT

usage() {
  echo "Usage: $0 <query>"
  echo
  echo "e.g. $0 'SELECT * FROM CI_SYSTEMOBJECTS'"
}

login() {
  local logon
  local token

  logon='{"username": "'$USERNAME'", "password": "'$PASSWORD'", "auth": "'$AUTH'"}'
  [[ $DEBUG != 0 ]] && echo "logon: $logon" >&2
  token=$(curl -Ss -H "Content-Type: application/json" -H "Accept: application/json" --data "$logon" "$BIPRWS/v1/logon/long")
  jq -r ".logontoken" <<< "$token"
}

logoff() {
  local token
  token="$1"
  uri="$BIPRWS/v1/logoff"

  [[ $DEBUG != 0 ]] && echo "logoff: v1/logoff" >&2
  curl -Ss -H "Content-Type: application/json" -H "Accept: application/json" -H "X-SAP-LogonToken: $token" --data "" "$uri"
}

cms_query() {
  local query
  local token
  local uri
  local query_debug

  token="$1"
  query_escaped=$(jq -R <<< "$2")
  query='{"query":'$query_escaped'}'
  uri="$3"
  query_debug="$4"
  [[ $query_debug != 0 ]] && echo "query: $query" >&2
  curl -Ss -H "Content-Type: application/json" -H "Accept: application/json" -H "X-SAP-LogonToken: $token" --data "$query" "$uri"
}

join_cms_queries() {
  local query_debug
  local token
  local query
  local uri
  local page
  local json
  local nexturi
  local lasturi

  token="$1"
  query="$2"
  uri="$3"
  protocol=$(cut -d: -f1 <<< "$uri")
  query_debug=$DEBUG
  page=1

  while true; do
    echo "uri $page: $uri" >&2
    json=$(cms_query "$token" "$query" "$uri" "$query_debug")
    query_debug=0
    [[ $DEBUG == 2 ]] && echo "$json" > debug.$page.json
    error_code=$(jq -r .error_code <<< "$json")
    message=$(jq -r .message <<< "$json")
    if [[ $error_code != 'null' ]]; then
        echo "error: $error_code: $message" >&2
        exit 2
    fi
    nexturi=$(jq -r .next.__deferred.uri <<< "$json" | sed "s/http:/${protocol}:/g")
    lasturi=$(jq -r .last.__deferred.uri <<< "$json" | sed "s/http:/${protocol}:/g")
    jq '.entries[]' <<< "$json"
    if [[ "$uri" == "$lasturi" || "$nexturi" == "null" ]]; then
      break
    fi
    if [[ "$uri" == "$nexturi" ]]; then
      echo "error: unexpected nexturi: $nexturi" >&2
      exit 2
    fi
    if (( page == 1000 )); then
      echo "error: reached page 1000"
      exit 2
    fi
    uri="$nexturi"
    page=$((page + 1))
  done
}

if [[ -z $1 ]]; then
  usage >&2
  exit 1
fi

if [[ -z $PASSWORD ]]; then
  echo "Please enter password for $USERNAME: " >&2
  read -rs PASSWORD
fi

query="$1"
uri="$BIPRWS/v1/cmsquery"
token="\"$(login)\""
BIPRWS_LOGON_TOKEN="$token"
[[ $DEBUG != 0 ]] && echo "token: $token" >&2

join_cms_queries "$token" "$query" "$uri" | jq -s
logoff "$token"
BIPRWS_LOGON_TOKEN=
