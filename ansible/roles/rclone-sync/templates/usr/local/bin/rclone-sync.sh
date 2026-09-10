#!/bin/bash
# Script to sync local directories using rclone with output logged to syslog
#
# Config file is pipe separated in format:
#   logprefix|frequency|arg1|arg2|arg3|...
#
# e.g.
#   [mycopy] |5m|copy|/my/source|myremote:/my/dest|--min-age=5m
#   [mycleanup] |1d|delete|myremote:/backup|--min-age=7d
#
# State:
#   Last attempted execution time for each log prefix is stored in:
#     /var/lib/rclone-sync/state
#
# Shared locking:
#   Since the script can run on multiple servers, a best efforts locking
#   mechanism is optionally implemented by atomic creation of a directory
#   on the shared file system. The lock directory is removed if it is
#   older than SHARED_LOCK_TIMEOUT to prevent an accidental permanent lock

CONFIG="/etc/rclone-sync.conf"
STATE_DIR="/var/lib/rclone-sync"
STATE_FILE="$STATE_DIR/state"
LOCAL_LOCK="/run/lock/rclone-sync.lock"
SHARED_LOCK="{{ rclone_sync_config.shared_lock | default() }}"
SHARED_LOCK_TIMEOUT=3600
ENABLE_MONITORING=0
ENABLE_FREQUENCY=0
VERBOSE=0
ERROR_BACKOFF_SECS=600
RCLONE_OPTS=()

{% raw %}
usage() {
  echo "Usage $0: [all|<job_key>] [-fms] [<rclone_arg1>] .. [<rclone_argN>]

Where:
   all:       run all jobs in $CONFIG
   <job_key>: run only the job matching job_key

All other options are passed through to rclone except:
   -m: enable monitoring, i.e. write status to /opt/textfile_monitoring
   -f: enable frequency, i.e. only run if frequency seconds have elapsed since last run
"
}

acquire_shared_lock() {
    local now
    local lock_time
    local lock_age

    if mkdir "$SHARED_LOCK" 2>/dev/null; then
        if ((VERBOSE > 1)); then
            echo "DEBUG: Acquired shared lock"
        fi
        return 0
    fi

    lock_time=$(stat -c %Y "$SHARED_LOCK" 2>/dev/null) || return 1
    now=$(date +%s)
    lock_age=$((now - lock_time))

    # Remove the lock if SHARED_LOCK_TIMEOUT seconds have elapsed since creation of the lock
    if (( lock_age > SHARED_LOCK_TIMEOUT )); then
        echo "Forcibly removing shared lock; age=${lock_age}s timeout=${SHARED_LOCK_TIMEOUT}s" >&2
        rmdir "$SHARED_LOCK" 2>/dev/null
    fi

    echo "Failed to get shared lock; age=${lock_age}s" >&2
    return 1
}

release_shared_lock() {
    # shellcheck disable=SC2317
    if rmdir "$SHARED_LOCK" 2>/dev/null; then
        if ((VERBOSE > 1)); then
            echo "DEBUG: Released shared lock"
        fi
    fi
}

set_job_timestamp() {
    local key
    local key_re
    local timestamp

    key=$1
    timestamp=$2
    key_re=$(printf '%s' "${key}" | sed 's/[][\/.^$*+?{}|()]/\\&/g')

    if [[ -f "$STATE_FILE" ]] && grep -q "^${key_re}=" "$STATE_FILE"; then
        sed -i "s|^${key_re}=.*|${key}=${timestamp}|" "$STATE_FILE"
    else
        echo "${key}=${timestamp}" >> "$STATE_FILE"
    fi
}

get_job_timestamp() {
    local key
    local key_re
    local timestamp

    key=$1
    key_re=$(printf '%s' "${key}" | sed 's/[][\/.^$*+?{}|()]/\\&/g')
    timestamp=$(sed -n "s|^${key_re}=||p" "$STATE_FILE" 2>/dev/null | head -n 1)
    if [[ -z "$timestamp" ]]; then
        echo 0
    else
        echo "$timestamp"
    fi
}

job_key_cmdline_arg=$1
if [[ -z $job_key_cmdline_arg || "$job_key_cmdline_arg" == -* ]]; then
    usage >&2
    exit 1
fi
shift

while [[ $# -gt 0 ]]; do
    case "$1" in
        -f)
            ENABLE_FREQUENCY=1
            shift
            ;;
        -m)
            ENABLE_MONITORING=1
            shift
            ;;
        --verbose)
            VERBOSE=$((VERBOSE + 1))
            RCLONE_OPTS+=("$1")
            shift
            ;;
        -v)
            VERBOSE=$((VERBOSE + 1))
            RCLONE_OPTS+=("$1")
            shift
            ;;
        -vv)
            VERBOSE=$((VERBOSE + 2))
            RCLONE_OPTS+=("$1")
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

if ! mkdir -p "$STATE_DIR"; then
    echo "Unable to create state directory: $STATE_DIR" >&2
    exit 1
fi

(
    flock -n 9 || {
        echo "Another rclone-sync is already running"
        exit 0
    }

    if [[ -n "$SHARED_LOCK" ]]; then
        shared_lock_parent=$(dirname "$SHARED_LOCK")
        if [[ ! -d "$shared_lock_parent" ]]; then
            echo "Shared lock parent does not exist: $shared_lock_parent" >&2
            exit 1
        fi
        fstype=$(stat -f -c %T "$shared_lock_parent")
        case "$fstype" in
            nfs|nfs4|cifs|smb2|smb3) ;;
            *)
                echo "Shared lock parent is not on a network filesystem: $fstype" >&2
                exit 1
                ;;
        esac

        acquire_shared_lock || exit 0
        trap release_shared_lock EXIT HUP INT TERM
    fi

    now=$(date +%s)
    line_num=0
    job_count=0
    overall_exitcode=0
    while IFS='|' read -ra fields
    do
        line_num=$((line_num + 1))
        job_key="${fields[0]:-}"

        # skip blank lines and comments
        [[ -z "$job_key" && ${#fields[@]} -eq 0 ]] && continue
        [[ "$job_key" =~ ^[[:space:]]*# ]] && continue

        if [[ ${#fields[@]} -lt 3 ]]; then
            echo "ERROR: $CONFIG: line ${line_num}: No rclone command specified" >&2
            overall_exitcode=1
            continue
        fi

        logprefix="[$job_key] "
        frequency="${fields[1]:-}"

        if [[ "$job_key_cmdline_arg" != "all" && "$job_key_cmdline_arg" != "$job_key" ]]; then
            if ((VERBOSE > 1)); then
                echo "${logprefix}DEBUG: Skipping as $job_key_cmdline_arg job requested"
            fi
            continue
        fi
        job_count=$((job_count+1))

        if [[ -n $frequency ]]; then
            if [[ ! "$frequency" =~ ^[0-9]+$ ]]; then
                echo "ERROR: $CONFIG: line ${line_num}: Frequency must be numeric: $frequency" >&2
                overall_exitcode=1
                continue
            fi
        else
            frequency=0
        fi

        if ((ENABLE_FREQUENCY == 1)); then
            timestamp=$(get_job_timestamp "$job_key")
            if ((now < timestamp)); then
                timestamp_diff=$((timestamp - now))
                if ((timestamp_diff > frequency && timestamp_diff > ERROR_BACKOFF_SECS)); then
                    echo "${logprefix}Frequency check: running; ${timestamp_diff}s too long to next run; frequency=$frequency; timestamp=$timestamp"
                else
                    if ((VERBOSE > 1)); then
                        echo "${logprefix}DEBUG: Frequency check: skipping; next run in ${timestamp_diff}s; frequency=$frequency; timestamp=$timestamp"
                    fi
                    continue
                fi
            else
                if ((VERBOSE > 1)); then
                    timestamp_diff=$((now - timestamp))
                    echo "${logprefix}DEBUG: Frequency check: running; ${timestamp_diff}s since last run; timestamp=$timestamp"
                fi
            fi
        fi

        # expand any $(date +format) in the config
        args=("${fields[@]:2}" "${RCLONE_OPTS[@]}")
        expanded_args=()
        date_regex='\$\(date[[:space:]]+\+([^)]+)\)'

        for arg in "${args[@]}"; do
            while [[ "$arg" =~ $date_regex ]]; do
                match="${BASH_REMATCH[0]}"
                format="${BASH_REMATCH[1]}"
                timestamp=$(date +"$format")
                arg="${arg//$match/$timestamp}"
            done
            expanded_args+=("$arg")
        done

        rclone "${expanded_args[@]}" 2>&1 | while IFS= read -r line; do
            [[ -n "$line" ]] && echo "${logprefix}$line"
        done

        exitcode=${PIPESTATUS[0]}
        if [[ "$exitcode" -ne 0 ]]; then
            overall_exitcode=$exitcode
            if ((ENABLE_FREQUENCY == 1)); then
                if ((VERBOSE > 1)); then
                    echo "${logprefix}DEBUG: Frequency check: setting next run in ${ERROR_BACKOFF_SECS}s (error backoff); timestamp=$((now + ERROR_BACKOFF_SECS))"
                fi
                set_job_timestamp "$job_key" "$((now + ERROR_BACKOFF_SECS))"
            fi
        else
            if ((ENABLE_FREQUENCY == 1)); then
                if ((VERBOSE > 1)); then
                    echo "${logprefix}DEBUG: Frequency check: setting next run in ${frequency}s; timestamp=$((now + frequency))"
                fi
                set_job_timestamp "$job_key" "$((now + frequency))"
            fi
        fi
    done < "$CONFIG"

    if [[ "$job_key_cmdline_arg" != "all" && $job_count -eq 0 ]]; then
        echo "ERROR: No matching jobs for $job_key_cmdline_arg" >&2
        overall_exitcode=1
    fi
    exit "$overall_exitcode"
) 9>"$LOCAL_LOCK"

overall_exitcode=$?

if (( ENABLE_MONITORING == 1 )); then
    if [[ -d /opt/textfile_monitoring ]]; then
        echo "rclone_sync_status $overall_exitcode" > /opt/textfile_monitoring/rclone_sync.prom
    fi
fi

exit "$overall_exitcode"
{% endraw %}
