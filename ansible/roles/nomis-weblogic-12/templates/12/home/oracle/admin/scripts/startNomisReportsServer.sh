#!/bin/bash

if [ -z "$1" ]; then
  echo "Usage: $0 <reports_server_name>"
  exit 1
fi

DOMAIN_HOME="/u01/app/oracle/Middleware/user_projects/domains/nomis"
BIN_DIR="$DOMAIN_HOME/bin"
SERVER_NAME="$1"
WLST_USERCONFIG="/u01/tmp/wlst.userconfig"
WLST_USERKEY="/u01/tmp/wlst.userkey"

generate_credentials() {
  /home/oracle/admin/scripts/createCredentialsFiles.sh
}

inject_nm_block() {
  FILE="$BIN_DIR/startComponent.sh"
  sed -i '/# BEGIN WLST NM CONNECT/,/# END WLST NM CONNECT/d' "$FILE"
  sed -i "/ComponentInternal/i \
# BEGIN WLST NM CONNECT\n\
echo \"  nmConnect(\" >> \"\${PY_LOC}\"\n\
echo \"    userConfigFile='$WLST_USERCONFIG',\" >> \"\${PY_LOC}\"\n\
echo \"    userKeyFile='$WLST_USERKEY',\" >> \"\${PY_LOC}\"\n\
echo \"    host='localhost',\" >> \"\${PY_LOC}\"\n\
echo \"    port=5556,\" >> \"\${PY_LOC}\"\n\
echo \"    domainName='nomis',\" >> \"\${PY_LOC}\"\n\
echo \"    nmType='ssl'\" >> \"\${PY_LOC}\"\n\
echo \"  )\" >> \"\${PY_LOC}\"\n\
# END WLST NM CONNECT" "$FILE"
}

cleanup() {
  FILE="$BIN_DIR/startComponent.sh"
  sed -i '/# BEGIN WLST NM CONNECT/,/# END WLST NM CONNECT/d' "$FILE"
  rm -f "$WLST_USERCONFIG" "$WLST_USERKEY"
}

generate_credentials
inject_nm_block
"$BIN_DIR/startComponent.sh" "$SERVER_NAME"
RETURN_VALUE=$?
cleanup
exit $RETURN_VALUE
