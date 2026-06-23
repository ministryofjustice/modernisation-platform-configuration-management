#!/bin/bash

DOMAIN_HOME=/u01/app/oracle/Middleware/user_projects/domains/nomis
SERVER=$1
PIDFILE=/tmp/$1.pid

case "$SERVER" in
{% for server in weblogic_domain_servers %}
  "{{ server.name }}")
    SERVER_JVM_ARGS="{{ server.jvm_args | default(weblogic_common_jvm_args) if (server.jvm_args | default(weblogic_common_jvm_args)) is string else (server.jvm_args | default(weblogic_common_jvm_args) | join(' ')) }}"
    ;;
{% endfor %}
  *)
    SERVER_JVM_ARGS="{{ weblogic_common_jvm_args if weblogic_common_jvm_args is string else weblogic_common_jvm_args | join(' ') }}"
    ;;
esac

export USER_MEM_ARGS="${USER_MEM_ARGS:-} ${SERVER_JVM_ARGS}"

is_server_running() {
  pgrep -u oracle -f "weblogic.Name=$1 " > /dev/null 2>&1
}

if is_server_running "$1"; then
  echo "$1 is already running; skipping startup"
  exit 0
fi

$DOMAIN_HOME/bin/startManagedWebLogic.sh $SERVER \
  > $DOMAIN_HOME/servers/$SERVER/logs/systemd-start.log 2>&1 &

sleep 10
pgrep -f "Dweblogic.Name=$SERVER" > "$PIDFILE"
exit 0