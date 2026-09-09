#!/bin/bash
# Script to sync local directories using rclone with output logged to syslog
#
# Config file is pipe separated in format:
#   logprefix|arg1|arg2|arg3|...
#
# e.g.
#   wmt|copy|/my/source|/my/dest|--dry-run
#
# Shared locking:
#   Since the script can run on multiple servers, a best efforts locking
#   mechanism is optionally implemented by atomic creation of a directory
#   on the shared file system. The lock directory is removed if it is
#   older than SHARED_LOCK_TIMEOUT to prevent an accidental permanent lock
#
# Usage:
#   rclone-sync [-ms] [rclone_arg1] .. [rclone_argN]
# Where:
#   -m: enable monitoring (write status to /opt/textfile_monitoring)
#   -s: add a date based --suffix and --suffix-keep-extension

CONFIG="/etc/rclone-sync.conf"
LOCAL_LOCK="/run/lock/rclone-sync.lock"
SHARED_LOCK="{{ rclone_sync_config.shared_lock | default() }}"
SHARED_LOCK_TIMEOUT=3600
OVERALL_EXITCODE=0
ENABLE_MONITORING=0
RCLONE_OPTS=()

acquire_shared_lock() {
    mkdir "$SHARED_LOCK" 2>/dev/null && return 0

    # Remove the lock if SHARED_LOCK_TIMEOUT seconds have elapsed since creation of the lock
    LOCK_TIME=$(stat -c %Y "$SHARED_LOCK" 2>/dev/null) || return 1
    NOW=$(date +%s)
    LOCK_AGE=$((NOW - LOCK_TIME))
    if (( LOCK_AGE > SHARED_LOCK_TIMEOUT )); then
      echo "Forcibly removing shared lock; age=${LOCK_AGE}s timeout=${SHARED_LOCK_TIMEOUT}s" >&2
      rmdir "$SHARED_LOCK" 2>/dev/null
    fi
    echo "Failed to get shared lock; age=${LOCK_AGE}s" >&2
    return 1
}

release_shared_lock() {
    # shellcheck disable=SC2317
    rmdir "$SHARED_LOCK" 2>/dev/null || true
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m)
      ENABLE_MONITORING=1
      shift
      ;;
    -s)
      RCLONE_OPTS+=("--suffix=-$(date +%F_%H%M%S)")
      RCLONE_OPTS+=("--suffix-keep-extension")
      shift
      ;;
    --)
      shift
      RCLONE_OPTS+=("$@")
      break
      ;;
    *)
      RCLONE_OPTS+=("$1")
      shift
      ;;
  esac
done

if [[ ! -f "$CONFIG" ]]; then
    echo "Configuration file not found: $CONFIG" >&2
    exit 1
fi

(
    flock -n 9 || {
        echo "Another synchronisation is already running"
        exit 0
    }

    if [[ -n "$SHARED_LOCK" ]]; then
        SHARED_LOCK_PARENT=$(dirname "$SHARED_LOCK")
        if [[ ! -d "$SHARED_LOCK_PARENT" ]]; then
            echo "Shared lock parent does not exist: $SHARED_LOCK_PARENT" >&2
            exit 1
        fi
        FSTYPE=$(stat -f -c %T "$SHARED_LOCK_PARENT")
        case "$FSTYPE" in
            nfs|nfs4|cifs|smb2|smb3) ;;
            *)
                echo "Shared lock parent is not on a network filesystem: $FSTYPE" >&2
                exit 1
                ;;
        esac

        acquire_shared_lock || exit 0
        trap release_shared_lock EXIT HUP INT TERM
    fi

    LINE_NUM=0
    while IFS='|' read -ra FIELDS
    do
        LINE_NUM=$((LINE_NUM + 1))
        LOGPREFIX="${FIELDS[0]:-}"

        {% raw %}
        # skip blank lines and comments
        [[ -z "$LOGPREFIX" && ${#FIELDS[@]} -eq 0 ]] && continue
        [[ "$LOGPREFIX" =~ ^[[:space:]]*# ]] && continue
        {% endraw %}

        rclone "${FIELDS[@]:1}" "${RCLONE_OPTS[@]}" 2>&1 | while IFS= read -r line; do
            [[ -n "$line" ]] && echo "${LOGPREFIX}$line"
        done

        EXITCODE=${PIPESTATUS[0]}
        if [[ "$EXITCODE" -ne 0 ]]; then
            OVERALL_EXITCODE=$EXITCODE
        fi
    done < "$CONFIG"
    exit "$OVERALL_EXITCODE"
) 9>"$LOCAL_LOCK"

OVERALL_EXITCODE=$?

if (( ENABLE_MONITORING == 1 )); then
    if [[ -d /opt/textfile_monitoring ]]; then
        echo "rclone_sync_status $OVERALL_EXITCODE" > /opt/textfile_monitoring/rclone_sync.prom
    fi
fi

exit $OVERALL_EXITCODE
