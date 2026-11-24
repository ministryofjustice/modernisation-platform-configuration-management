#!/bin/bash
# Script to sync local directories using rclone with output logged to syslog
#
# Config file is pipe separated in format:
#   jobkey|arg1|arg2|arg3|...
#
# e.g.
#   mycopy|copy|/my/source|myremote:/my/dest|--min-age=5m # run at 15 minutes past the hour
#   mycleanup|delete|myremote:/backup|--min-age=7d        # run daily
#
# Use the script to run rclone one or all of the jobs specified in the config
# with option to add additonal parameters as needed, e.g.
#   rclone-sync.sh mycopy --dry-run
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
#
# Script specific options (--rclone-sync options)
#   --rclone-sync-frequency-interval <seconds>        - run job with this frequency
#   --rclone-sync-frequency-offset   <seconds>        - specify exact time to run, e.g. number of seconds past the hour if frequency=3600
#   --rclone-sync-maintenance-window                  - d.HHMM-d.HHMM, don't run during maintenance window
#   --rclone-error-backoff                            - if an error, retry in this number of seconds rather than on the next run
#   --rclone-alarm-after-consecutive-error-count      - only alarm after this number of consecutive errors
#   --rclone-sync-move-after-consecutive-error-count  - use moveto if a copy/sync if repeatedly failing

CONFIG="/etc/rclone-sync.conf"
STATE_DIR="/var/lib/rclone-sync"
STATE_FILE="$STATE_DIR/state"
ERROR_FILE="$STATE_DIR/error"
LOCAL_LOCK="/run/lock/rclone-sync.lock"
SHARED_LOCK="{{ rclone_sync_config.shared_lock | default() }}"
SHARED_LOCK_TIMEOUT=3600
ENABLE_MONITORING=0
ENABLE_FREQUENCY=0
ENABLE_MAINTENANCE_WINDOW_CHECK=1
VERBOSE=0
RCLONE_OPTS=()

# START (raw section){% raw %}

usage() {
  echo "Usage $0: [all|<job_key>] [-fm] [<rclone_arg1>] .. [<rclone_argN>]

Where:
   all:       run all jobs in $CONFIG
   <job_key>: run only the job matching job_key

All other options are passed through to rclone except:
   -m: enable monitoring, i.e. write status to /opt/textfile_monitoring
   -f: enable frequency, i.e. only run if frequency_interval seconds have elapsed since last run
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

# shellcheck disable=SC2317
# shellcheck disable=SC2329
release_shared_lock() {
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

set_job_error_count() {
    local key
    local key_re
    local error

    key=$1
    error=$2
    key_re=$(printf '%s' "${key}" | sed 's/[][\/.^$*+?{}|()]/\\&/g')

    if [[ -f "$ERROR_FILE" ]] && grep -q "^${key_re}=" "$ERROR_FILE"; then
        sed -i "s|^${key_re}=.*|${key}=${error}|" "$ERROR_FILE"
    else
        echo "${key}=${error}" >> "$ERROR_FILE"
    fi
}

get_job_error_count() {
    local key
    local key_re
    local error

    key=$1
    key_re=$(printf '%s' "${key}" | sed 's/[][\/.^$*+?{}|()]/\\&/g')
    error=$(sed -n "s|^${key_re}=||p" "$ERROR_FILE" 2>/dev/null | head -n 1)
    if [[ -z "$error" ]]; then
        echo 0
    else
        echo "$error"
    fi
}

reset_job_failed_file() {
    local key
    local count
    local i
    local f

    key=$1
    count=$2

    mkdir -p "$STATE_DIR/failed/$key"
    for f in "$STATE_DIR/failed/$key"/failed.*.txt; do
        if [[ $f =~ failed\.([0-9]+)\.txt ]]; then
            if (( BASH_REMATCH[1] >= count )); then
                rm -f "$f"
            fi
        fi
    done
    for ((i=count-1; i>0; i=i-1)); do
        if [[ -e "$STATE_DIR/failed/$key/failed.$i.txt" ]]; then
            mv "$STATE_DIR/failed/$key/failed.$i.txt" "$STATE_DIR/failed/$key/failed.$((i+1)).txt"
        fi
    done
    touch "$STATE_DIR/failed/$key/failed.1.txt"
}

add_job_failed_file() {
    local key
    local file

    key=$1
    file=$2
    if ! grep -Fqx "$file" "$STATE_DIR/failed/$key/failed.1.txt"; then
        echo "$file" >> "$STATE_DIR/failed/$key/failed.1.txt"
    fi
}

# shellcheck disable=SC2126
get_job_failed_files() {
    local key
    local count
    local failed_file
    local consecutive_failure_count

    key=$1
    count=$2

    if [[ -f "$STATE_DIR/failed/$key/failed.1.txt" ]]; then
        while IFS= read -r failed_file; do
            [[ -z "$failed_file" ]] && continue
            consecutive_failure_count=$(grep -Fx "$failed_file" "$STATE_DIR/failed/$key"/failed.*.txt | wc -l)
            if [[ $consecutive_failure_count -eq $count ]]; then
                echo "$failed_file"
            fi
        done < "$STATE_DIR/failed/$key/failed.1.txt"
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
    date_regex='\$\(date[[:space:]]+\+([^)]+)\)'
    argvalue_regex='^(--[^=]+)=(.*)$'

    while IFS='|' read -ra fields
    do
        line_num=$((line_num + 1))
        job_key="${fields[0]:-}"

        # skip blank lines and comments
        [[ -z "$job_key" && ${#fields[@]} -eq 0 ]] && continue
        [[ "$job_key" =~ ^[[:space:]]*# ]] && continue

        logprefix="[$job_key] "

        if [[ "$job_key_cmdline_arg" != "all" && "$job_key_cmdline_arg" != "$job_key" ]]; then
            if ((VERBOSE > 1)); then
                echo "${logprefix}DEBUG: Skipping as $job_key_cmdline_arg job requested"
            fi
            continue
        fi

        job_count=$((job_count+1))
        frequency_interval=0
        frequency_offset=
        alarm_after_consecutive_error_count=
        move_after_consecutive_error_count=
        maintenance_window=
        error_backoff=
        suffix=
        exitcode=
        rclone_cmds=()
        rclone_args=()

        # parse args stripping out any rclone-sync specifc args and expanding any dates
        for arg in "${fields[@]:1}" "${RCLONE_OPTS[@]}"; do
            if [[ "$arg" == -* ]]; then
                while [[ "$arg" =~ $date_regex ]]; do
                    match="${BASH_REMATCH[0]}"
                    format="${BASH_REMATCH[1]}"
                    timestamp=$(date +"$format")
                    arg="${arg//$match/$timestamp}"
                done
                if [[ "$arg" =~ $argvalue_regex ]]; then
                    argname="${BASH_REMATCH[1]}"
                    argvalue="${BASH_REMATCH[2]}"
                    case "$argname" in
                        --rclone-sync-frequency-interval)
                            if [[ ! "$argvalue" =~ ^[0-9]+$ ]]; then
                                echo "${logprefix}ERROR: $CONFIG: line ${line_num}: $argname must be numeric, got: $argvalue" >&2
                                exitcode=1
                            else
                                frequency_interval="$argvalue"
                            fi
                            ;;
                        --rclone-sync-frequency-offset)
                            if [[ ! "$argvalue" =~ ^[0-9]+$ ]]; then
                                echo "${logprefix}ERROR: $CONFIG: line ${line_num}: $argname must be numeric, got: $argvalue" >&2
                                exitcode=1
                            else
                                frequency_offset="$argvalue"
                            fi
                            ;;
                        --rclone-sync-maintenance-window)
                            maintenance_window="$argvalue"
                            ;;
                        --rclone-error-backoff)
                            if [[ ! "$argvalue" =~ ^[0-9]+$ ]]; then
                                echo "${logprefix}ERROR: $CONFIG: line ${line_num}: $argname must be numeric, got: $argvalue" >&2
                                exitcode=1
                            else
                                error_backoff="$argvalue"
                            fi
                            ;;
                        --rclone-alarm-after-consecutive-error-count)
                            if [[ ! "$argvalue" =~ ^[0-9]+$ ]]; then
                                echo "${logprefix}ERROR: $CONFIG: line ${line_num}: $argname must be numeric, got: $argvalue" >&2
                                exitcode=1
                            else
                                alarm_after_consecutive_error_count="$argvalue"
                            fi
                            ;;
                        --rclone-sync-move-after-consecutive-error-count)
                            if [[ ! "$argvalue" =~ ^[0-9]+$ ]]; then
                                echo "${logprefix}ERROR: $CONFIG: line ${line_num}: $argname must be numeric, got: $argvalue" >&2
                                exitcode=1
                            else
                                move_after_consecutive_error_count="$argvalue"
                            fi
                            ;;
                        --suffix)
                            suffix=$argvalue
                            rclone_args+=("$arg")
                            ;;
                        *)
                            if [[ $argname =~ --rclone-sync ]]; then
                                echo "${logprefix}ERROR: $CONFIG: line ${line_num}: Unsupported rclone-sync arg $argname" >&2
                                exitcode=1
                            else
                                rclone_args+=("$arg")
                            fi
                    esac
                else
                    rclone_args+=("$arg")
                fi
            else
                rclone_cmds+=("$arg")
            fi
        done

        if [[ ${#rclone_cmds[@]} -eq 0 ]]; then
            echo "${logprefix}ERROR: $CONFIG: line ${line_num}: No rclone command specified" >&2
            exitcode=1
        fi

        if ((ENABLE_FREQUENCY == 1)); then
            timestamp=$(get_job_timestamp "$job_key")
            if ((now < timestamp)); then
                timestamp_diff=$((timestamp - now))
                if ((timestamp_diff > frequency_interval && timestamp_diff > ERROR_BACKOFF_SECS)); then
                    echo "${logprefix}Frequency check: running; ${timestamp_diff}s too long to next run; frequency_interval=${frequency_interval}s; timestamp=$timestamp"
                else
                    if ((VERBOSE > 1)); then
                        echo "${logprefix}DEBUG: Frequency check: skipping; next run in ${timestamp_diff}s; frequency_interval=${frequency_interval}s; timestamp=$timestamp"
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

        if ((ENABLE_MAINTENANCE_WINDOW_CHECK == 1)); then
            if [[ -n $maintenance_window ]]; then
                now_utc=$(date -u +%u.%H%M)
                IFS=- read -r -a maintenance_times <<< "$maintenance_window"
                if [[ ($now_utc == "${maintenance_times[0]}" || $now_utc > "${maintenance_times[0]}") && $now_utc < "${maintenance_times[1]}" ]]; then
                    echo "${logprefix}DEBUG: Skipping check in maintenance window $now_utc in [${maintenance_times[0]},${maintenance_times[1]}]"
                    continue
                fi
            fi
        fi

        if [[ -n "$move_after_consecutive_error_count" ]]; then
            reset_job_failed_file "$job_key" "$move_after_consecutive_error_count"
        fi

        if [[ -z "$exitcode" ]]; then
            # run rclone but capture failures due to upload session was not found - it seems this can block some uploads
            pattern1="ERROR : ([^:]+): Failed to copy:.*The upload session was not found"
            pattern2="NOTICE: ([^:]+): Failed to cancel multipart upload" # suppress from logs
            rclone "${rclone_cmds[@]}" "${rclone_args[@]}" 2>&1 | while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    if [[ ! "$line" =~ $pattern2 || $VERBOSE -gt 1 ]]; then
                        echo "${logprefix}$line"
                    fi
                    if [[ -n "$move_after_consecutive_error_count" && "$line" =~ $pattern1 ]]; then
                        failed_file="${BASH_REMATCH[1]}"
                        add_job_failed_file "$job_key" "$failed_file"
                    fi
                fi
            done
            exitcode=${PIPESTATUS[0]}

            # Workaround for files that fail due to upload session was not found
            if [[ -n "$move_after_consecutive_error_count" ]]; then
                failed_files=$(get_job_failed_files "$job_key" "$move_after_consecutive_error_count")
                while IFS= read -r failed_file; do
                    [[ -z "$failed_file" ]] && continue
                    if [[ ${rclone_cmds[0]} != "copy" && ${rclone_cmds[0]} != "sync" ]]; then
                        echo "${logprefix}ERROR: $CONFIG: line ${line_num}: expected copy or sync cmd with --rclone-sync-move-after-consecutive-error-count: $failed_file" >&2
                    elif [[ -z "$suffix" ]]; then
                        echo "${logprefix}ERROR: $CONFIG: line ${line_num}: --suffix must be specified with --rclone-sync-move-after-consecutive-error-count: $failed_file" >&2
                    elif [[ ${#rclone_cmds[@]} -lt 2 ]]; then
                        echo "${logprefix}ERROR: $CONFIG: line ${line_num}: missing dest arg, cannot --rclone-sync-move-after-consecutive-error-count: $failed_file" >&2
                    else
                        src="${rclone_cmds[1]}"
                        dest="${rclone_cmds[2]}"
                        base="${failed_file%.*}"
                        ext="${failed_file##*.}"
                        backup_file="${base}${suffix}.${ext}"
                        rclone moveto "$dest/$failed_file" "$dest/$backup_file" --verbose --stats=0 --retries=0 --low-level-retries=0 2>&1 | while IFS= read -r line; do
                            [[ -n "$line" ]] && echo "${logprefix}move_after_consecutive_error_count=$move_after_consecutive_error_count: $line"
                        done
                        if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
                            rclone copyto "$src/$failed_file" "$dest/$failed_file" --verbose --stats=0 --retries=0 --low-level-retries=0 --ignore-size --ignore-checksum 2>&1 | while IFS= read -r line; do
                                [[ -n "$line" ]] && echo "${logprefix}move_after_consecutive_error_count=$move_after_consecutive_error_count: $line"
                            done
                        fi
                    fi
                done <<< "$failed_files"
            fi
        fi

        error_count=$(get_job_error_count "$job_key")
        if [[ "$exitcode" -ne 0 ]]; then
            error_count=$((error_count+1))
        else
            if (( error_count > 1 )); then
               echo "${logprefix}INFO: successfully ran after consecutive_error_count=$error_count"
            fi
            error_count=0
        fi
        set_job_error_count "$job_key" "$error_count"

        if (( ENABLE_MONITORING == 1 )); then
            if [[ -d /opt/textfile_monitoring/rclone_sync ]]; then
                if [[ -z $alarm_after_consecutive_error_count ]]; then
                    echo "$job_key $exitcode" > "/opt/textfile_monitoring/rclone_sync/$job_key.metric"
                elif [[ $error_count -gt $alarm_after_consecutive_error_count ]]; then
                    echo "$job_key $exitcode" > "/opt/textfile_monitoring/rclone_sync/$job_key.metric"
                else
                    echo "$job_key 0" > "/opt/textfile_monitoring/rclone_sync/$job_key.metric"
                fi
            fi
        fi

        if [[ "$exitcode" -ne 0 ]]; then
            overall_exitcode=$exitcode
            if ((ENABLE_FREQUENCY == 1)); then
                if [[ -n $error_backoff ]]; then
                    if ((VERBOSE > 1)); then
                        echo "${logprefix}DEBUG: Frequency check: setting next run in ${error_backoff}s (error backoff); timestamp=$((now + error_backoff))"
                    fi
                    set_job_timestamp "$job_key" "$((now + error_backoff))"
                fi
            fi
        else
            if ((ENABLE_FREQUENCY == 1)); then
                if [[ -n $frequency_offset ]]; then
                    # round time to the next frequency_interval + frequency_offset
                    now_less_offset=$((now - frequency_offset))
                    next_time=$(( now_less_offset - (now_less_offset % frequency_interval) + frequency_interval + frequency_offset ))
                else
                    next_time=$((now + frequency_interval))
                fi
                if ((VERBOSE > 1)); then
                    echo "${logprefix}DEBUG: Frequency check: setting next run in $((next_time - now))s; timestamp=${next_time}; $(date -d @${next_time} +%T)"
                fi
                set_job_timestamp "$job_key" "$next_time"
            fi
        fi
    done < "$CONFIG"

    if [[ "$job_key_cmdline_arg" != "all" && $job_count -eq 0 ]]; then
        echo "ERROR: No matching jobs for $job_key_cmdline_arg" >&2
        overall_exitcode=1
    fi
    exit "$overall_exitcode"
) 9>"$LOCAL_LOCK"

exit $?

# END (raw section){% endraw %}
