#!/bin/bash
set -e
SERVER="AdminServer"

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

if is_server_running "$SERVER"; then
  echo "$SERVER is already running; skipping startup"
  exit 0
fi

echo "/u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startWebLogic.sh"
nohup /u01/app/oracle/Middleware/user_projects/domains/nomis/bin/startWebLogic.sh &
echo "Waiting for RUNNING"
/home/oracle/admin/scripts/wait_for_entry_in_journal.sh weblogic-server RUNNING

