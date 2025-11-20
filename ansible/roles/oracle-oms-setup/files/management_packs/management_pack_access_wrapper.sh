#!/usr/bin/env bash
# exec the real program as target user, with stdin/stdout connected to rsyslog
exec /sbin/runuser /bin/bash -u oracle -- /home/oracle/admin/em/management_pack_access.sh