#!/bin/bash

set -e

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
  FILE="$BIN_DIR/stopComponent.sh"
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

check_state() {
  java weblogic.WLST <<EOF 2>/dev/null | \
  grep -E "RUNNING|STARTING|RESTARTING|SHUTDOWN|UNKNOWN" | \
  tail -1 | tr -d '\r'
nmConnect(userConfigFile='$WLST_USERCONFIG',
          userKeyFile='$WLST_USERKEY',
          host='localhost',
          port=5556,
          domainName='nomis',
          nmType='ssl')
print nmServerStatus('$SERVER_NAME')
exit()
EOF
}

cleanup() {
  sed -i '/# BEGIN WLST NM CONNECT/,/# END WLST NM CONNECT/d' "$BIN_DIR/stopComponent.sh"
  rm -f "$WLST_USERCONFIG" "$WLST_USERKEY"
}

generate_credentials
inject_nm_block

STATE=$(check_state)
echo "Initial state: [$STATE]"

if echo "$STATE" | grep -Eq "RUNNING|STARTING|RESTARTING"; then
  echo "Stopping $SERVER_NAME..."
  "$BIN_DIR/stopComponent.sh" "$SERVER_NAME"
else
  echo "$SERVER_NAME already stopped (state: $STATE)"
fi

echo "Waiting for $SERVER_NAME to fully shutdown..."

MAX_WAIT=300
WAITED=0

while true; do
  STATE=$(check_state)
  echo "Current state: [$STATE]"

  if ! echo "$STATE" | grep -Eq "RUNNING|STARTING|RESTARTING"; then
    echo "$SERVER_NAME is fully stopped."
    break
  fi

  sleep 5
  WAITED=$((WAITED+5))

  if [ $WAITED -ge $MAX_WAIT ]; then
    echo "Timeout waiting for shutdown!"
    cleanup
    exit 1
  fi
done

cleanup
exit 0
