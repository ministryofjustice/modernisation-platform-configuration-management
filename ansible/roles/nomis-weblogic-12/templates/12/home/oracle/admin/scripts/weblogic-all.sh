#!/bin/bash
#
# weblogic-all        Startup script for all weblogic components
#
# chkconfig: - 85 15
# description: weblogic server

# Source function library.
. /etc/init.d/functions

prog="weblogic-all"

start_parallel() {
  set -e
  echo $"Starting all weblogic processes: "
  touch /var/lock/subsys/$prog

  [[ -e /etc/systemd/system/weblogic-node-manager.service ]] && systemctl start weblogic-node-manager
  [[ -e /etc/systemd/system/weblogic-server.service ]] && systemctl start weblogic-server
  [[ -e /etc/systemd/system/weblogic-ohs.service ]] && systemctl start weblogic-ohs

  managed_services=$(find /etc/systemd/system/ -name 'WLS*.service' -exec basename {} \; | sort)
  echo -n $"Starting all WLS services in parallel: "
  i=0
  for managed_service in $managed_services; do
    systemctl start "$managed_service" > /dev/null 2>&1 &
    pids[i]=$!
    i=$((i + 1))
  done
  echo "PIDS ${pids[*]}"

  set +e
  i=0
  for managed_service in $managed_services; do
    echo -n $"Waiting for $managed_service: PID=${pids[i]}"
    if ! wait ${pids[i]}; then
      echo_failure
      echo
      return 1
    fi
    echo_success
    echo
    i=$((i + 1))
  done
  set -e
}

start_sequential() {
  set -e
  echo $"Starting all weblogic processes: "
  touch /var/lock/subsys/$prog
  [[ -x /etc/systemd/system/weblogic-node-manager.service ]] && systemctl start weblogic-node-manager
  [[ -x /etc/systemd/system/weblogic-server.service ]] && systemctl start weblogic-server
  managed_services=$(find /etc/systemd/system/ -name 'WLS*.service' -exec basename {} \; | sort)
  for managed_service in $managed_services; do
    systemctl start "$managed_service"
  done
  [[ -x /etc/systemd/system/weblogic-ohs.service ]] && systemctl start weblogic-ohs
}

start() {
  start_parallel
}

stop() {
  echo $"Stopping all weblogic processes: "
  rm -f /var/lock/subsys/$prog
  managed_services=$(find /etc/systemd/system/ -name 'WLS*.service' -exec basename {} \; | sort)
  for managed_service in $managed_services; do
    systemctl stop "$managed_service"
  done
  [[ -x /etc/systemd/system/weblogic-server.service ]] && systemctl stop weblogic-server
  [[ -x /etc/systemd/system/weblogic-ohs.service ]] && systemctl stop weblogic-ohs
  [[ -x /etc/systemd/system/weblogic-node-manager.service ]] && systemctl stop weblogic-node-manager
  pkill -9 -u oracle frmweb
}

status() {
  RETVAL=0
  echo $"Status of all weblogic processes:"
  if [[ -x /etc/systemd/system/weblogic-node-manager.service ]]; then
    if ! systemctl status weblogic-node-manager; then
      RETVAL=1
    fi
  fi
  if [[ -x /etc/systemd/system/weblogic-ohs.service ]]; then
      if ! systemctl status weblogic-ohs; then
        RETVAL=1
      fi
    fi
  if [[ -x /etc/systemd/system/weblogic-server.service ]]; then
    if ! systemctl status weblogic-server; then
      RETVAL=1
    fi
  fi
  managed_services=$(find /etc/systemd/system/ -name 'WLS*.service' -exec basename {} \; | sort)
  for managed_service in $managed_services; do
    if ! systemctl status "$managed_service"; then
      RETVAL=1
    fi
  done
  return $RETVAL
}

restart() {
  stop
  start
}


get_unhealthy_services() {
  unhealthy=()
  if [[ -x /etc/systemd/system/weblogic-node-manager.service ]]; then
    if ! systemctl is-active --quiet weblogic-node-manager > /dev/null; then
      unhealthy+=(weblogic-node-manager)
    fi
  fi
  if [[ -x /etc/systemd/system/weblogic-ohs.service ]]; then
    if ! systemctl is-active --quiet weblogic-ohs > /dev/null; then
      unhealthy+=(weblogic-ohs)
    fi
  fi
  if [[ -x /etc/systemd/system/weblogic-server.service ]]; then
    ok=1
    weblogic_server_status=$(systemctl status weblogic-server)
    if ! echo "$weblogic_server_status" | head -1 | grep OK > /dev/null; then
      ok=0
    fi
    if ! echo "$weblogic_server_status" | grep -w AdminServer | grep RUNNING > /dev/null; then
      ok=0
    fi
    if (( ! ok )); then
      unhealthy+=(weblogic-server)
    fi
  fi
  managed_services=$(find /etc/systemd/system/ -name 'WLS*.service' -exec basename {} \; | sort)
  for managed_service in $managed_services; do
    ok=1
    if ! systemctl is-active --quiet "$managed_service" > /dev/null; then
      ok=0
    fi
    if ! echo "$weblogic_server_status" | grep -w "$managed_service" | grep RUNNING > /dev/null; then
      ok=0
    fi
    if (( ! ok )); then
      unhealthy+=("$managed_service")
    fi
  done
  echo "${unhealthy[@]}"
}

healthcheck() {
  unhealthy_services=$(get_unhealthy_services)
  if [[ -z $unhealthy_services ]]; then
    echo -n $"Healthcheck of weblogic-all: "
    echo_success
    echo
    return 0
  else
    for service in $unhealthy_services; do
      echo -n $"Healthcheck of $service: "
      echo_failure
      echo
    done
    return 1
  fi
}

repair() {
  unhealthy_services=$(get_unhealthy_services)
  if [[ -z $unhealthy_services ]]; then
    echo "All services healthy, nothing to repair"
    return 0
  fi
  for service in $unhealthy_services; do
    systemctl restart "$service"
  done
  unhealthy_services=$(get_unhealthy_services)
  if [[ -z $unhealthy_services ]]; then
    echo "All services repaired"
    return 0
  fi
  echo "Failed to repair: $unhealthy_services"
  return 1
}

case "$1" in
  start)
    start
    repair
    unhealthy_services=$(get_unhealthy_services)
    if [[ -n $unhealthy_services ]]; then
      status
      echo "Re-starting all services in attempt to fix $unhealthy_services"
      stop
      start
      repair
    fi
    ;;
  start_sequential)
    start_sequential
    ;;
  start_parallel)
    start_parallel
    ;;
  stop)
    stop
    ;;
  restart)
    restart
    ;;
  status)
    status
    ;;
  healthcheck)
    healthcheck
    ;;
  repair)
    repair
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|healthcheck|repair|start_sequential|start_parallel}"
    exit 3
esac

exit $?
