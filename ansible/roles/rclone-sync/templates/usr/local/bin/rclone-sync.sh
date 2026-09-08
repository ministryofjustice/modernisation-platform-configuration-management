#!/bin/bash
# Script to sync local directories using rclone with output logged to syslog
#
# Config file is pipe separated in format:
#   cmd|logprefix|source|target|arg1|arg2|arg3|...
#
# Each argument after target is passed to rclone as a separate argument.
#
# Shared locking:
#   Since the script can run on multiple servers, a best efforts locking
#   mechanism is optionally implemented by atomic creation of a directory
#   on the shared file system. The lock directory is removed if it is
#   older than SHARED_LOCK_TIMEOUT to prevent an accidental permanent lock

CONFIG="/etc/rclone-sync.conf"
LOCAL_LOCK="/run/lock/rclone-sync.lock"
SHARED_LOCK="{{ rclone_sync_config.shared_lock | default() }}"
SHARED_LOCK_TIMEOUT=3600
OVERALL_EXITCODE=0
RCLONE_DRYUN_ARG=
ENABLE_MONITORING=0

usage() {
  echo "Usage $0: <opts>

Where <opts>:
  -d  Enable dryrun for maintenance mode commands
  -m  Write status to /opt/textfile_monitoring
"
}

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

while getopts "dm" opt; do
    case $opt in
        d)
            RCLONE_DRYUN_ARG="--dry-run"
            ;;
        m)
            ENABLE_MONITORING=1
            ;;
        ?)
            echo "Invalid option: ${OPTARG}" >&2
            echo >&2
            usage >&2
            exit 1
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

        {% raw %}
        CMD="${FIELDS[0]:-}"
        [[ -z "$CMD" && ${#FIELDS[@]} -eq 0 ]] && continue
        [[ "$CMD" =~ ^[[:space:]]*# ]] && continue

        if [[ ${#FIELDS[@]} -lt 4 ]]; then
            echo "line $LINE_NUM: Invalid config line (expected at least 4 fields)" >&2
            OVERALL_EXITCODE=1
            continue
        fi
        {% endraw %}

        LOGPREFIX="${FIELDS[1]}"
        SRC="${FIELDS[2]}"
        DST="${FIELDS[3]}"
        ARGS=("${FIELDS[@]:4}")

        if [[ -z "$CMD" || -z "$SRC" || -z "$DST" ]]; then
            echo "${LOGPREFIX}line $LINE_NUM: Invalid config line (empty cmd, src or dst)" >&2
            OVERALL_EXITCODE=1
            continue
        fi

        if [[ ! -d "$SRC" ]]; then
            echo "${LOGPREFIX}source directory is not accessible '$SRC'" >&2
            OVERALL_EXITCODE=1
            continue
        fi

        rclone "$CMD" "$SRC" "$DST" "${ARGS[@]}" "$RCLONE_DRYUN_ARG" 2>&1 |
        while IFS= read -r line
        do
            [[ -n "$line" ]] && echo "${LOGPREFIX}$line"
        done

        EXITCODE=${PIPESTATUS[0]}

        if [[ "$EXITCODE" -ne 0 ]]; then
            echo "${LOGPREFIX}rclone $CMD '$SRC' '$DST' ${ARGS[*]}: failed with exit code $EXITCODE" >&2
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
