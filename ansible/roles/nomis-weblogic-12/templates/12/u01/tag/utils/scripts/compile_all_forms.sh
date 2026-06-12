#!/usr/bin/env bash

set -u

batch_size=30
batch_sleep=1
sleep_between_file_types=2
parallel_jobs=10
start_index=0
forms_source_dir="/u01/tag/FormsSources"
log_dir="/tmp/forms_compile_logs"

username=""
password=""
target_db=""

for arg in "$@"; do
    case "$arg" in
        batch_size=*) batch_size="${arg#*=}" ;;
        batch_sleep=*) batch_sleep="${arg#*=}" ;;
        parallel_jobs=*) parallel_jobs="${arg#*=}" ;;
        start_index=*) start_index="${arg#*=}" ;;
        sleep_between_file_types=*) sleep_between_file_types="${arg#*=}" ;;
        forms_source_dir=*) forms_source_dir="${arg#*=}" ;;
        log_dir=*) log_dir="${arg#*=}" ;;
        username=*) username="${arg#*=}" ;;
        password=*) password="${arg#*=}" ;;
        target_db=*) target_db="${arg#*=}" ;;
        *) echo "Warning: unknown argument ignored: $arg" ;;
    esac
done

usage() {
    echo "Usage: $0 username=<user> password=<password> target_db=<db> [parallel_jobs=5] [batch_size=30]"
}

if [[ -z "$username" || -z "$password" || -z "$target_db" ]]; then
    echo "Error: missing username, password or target_db"
    usage
    exit 1
fi

validate_non_negative_integer() {
    local value="$1"
    local name="$2"
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "Error: $name must be a non-negative integer"
        exit 1
    fi
}

validate_positive_integer() {
    local value="$1"
    local name="$2"
    if ! [[ "$value" =~ ^[0-9]+$ ]] || (( value < 1 )); then
        echo "Error: $name must be a positive integer"
        exit 1
    fi
}

validate_positive_integer "$parallel_jobs" "parallel_jobs"
validate_non_negative_integer "$batch_size" "batch_size"
validate_non_negative_integer "$batch_sleep" "batch_sleep"
validate_non_negative_integer "$sleep_between_file_types" "sleep_between_file_types"
validate_non_negative_integer "$start_index" "start_index"

if [[ -z "${ORACLE_HOME:-}" ]]; then
    echo "Error: ORACLE_HOME is not set"
    exit 1
fi

if [[ ! -d "$forms_source_dir" ]]; then
    echo "Error: forms source directory does not exist: $forms_source_dir"
    exit 1
fi

export TNS_ADMIN="${TNS_ADMIN:-$ORACLE_HOME/network/admin}"
export LD_LIBRARY_PATH="$ORACLE_HOME/lib:${LD_LIBRARY_PATH:-}"
export TERM="${TERM:-vt220}"
export ORACLE_TERM="${ORACLE_TERM:-vt220}"
export FORMS_PATH="$forms_source_dir:${FORMS_PATH:-}"

# The old compform.sh deliberately unset these so frmcmp_batch used its default NLS_LANG.
unset LANG
unset NLS_LANG

mkdir -p "$log_dir"
cd "$forms_source_dir" || exit 1

if ! command -v frmcmp_batch >/dev/null 2>&1; then
    echo "Error: Cannot find Oracle Forms compiler frmcmp_batch. Check ORACLE_HOME and PATH."
    exit 1
fi

connect_string="$username/$password@$target_db"

# Validate the database connection once. The old compform.sh did this for every file.
echo "Checking database connection once..."
checkoms=$(sqlplus -s "$connect_string" <<'SQLSCRIPT'
set heading off feedback off pagesize 0 verify off echo off
select 'OMS_OWNER' from dual;
exit
SQLSCRIPT
)

if [[ "$(echo "$checkoms" | awk '{ print $1 }')" != "OMS_OWNER" ]]; then
    echo "Error: unable to login to database using supplied parameters"
    exit 1
fi

echo "Database connection OK"

# Fetch NLS length semantics once. The old compform.sh did this for every file.
echo "Reading nls_length_semantics once..."
nls_value=$(sqlplus -s "$connect_string" <<'SQLSCRIPT'
set heading off feedback off pagesize 0 verify off echo off
select value from v$parameter where name = 'nls_length_semantics';
exit
SQLSCRIPT
)
nls_value="$(echo "$nls_value" | awk 'NF {print $1; exit}')"

if [[ -z "$nls_value" ]]; then
    echo "Warning: Could not determine nls_length_semantics; leaving NLS_LENGTH_SEMANTICS unset"
else
    export NLS_LENGTH_SEMANTICS="$nls_value"
    echo "NLS_LENGTH_SEMANTICS=$NLS_LENGTH_SEMANTICS"
fi

all_failures_file="$(mktemp /tmp/compile_all_forms_failures.XXXXXX)"

compile_one() {
    local file_name="$1"
    local module_type="$2"
    local output_file="$3"
    local err_file="${file_name%.*}.err"
    local log_file="$log_dir/${file_name}.log"
    local rc

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting compile: $file_name type=$module_type"

    rm -f "$output_file" "$err_file"

    frmcmp_batch \
        module="$file_name" \
        module_type="$module_type" \
        userid="$connect_string" \
        batch=YES \
        compile_all=YES \
        > "$log_file" 2>&1

    rc=$?

    if [[ -f "$err_file" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Last error line for $file_name: $(tail -1 "$err_file")" >> "$log_file"
    fi

    # For Forms, frmcmp_batch can occasionally return a non-zero rc even though
    # the .fmx was produced successfully. Because we delete the output before
    # compiling, a readable output file here means this run created it.
    if [[ -r "$output_file" ]]; then
        if (( rc == 0 )); then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $file_name -> $output_file"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $file_name returned rc=$rc but output exists: $output_file. Treating as success. See log=$log_file"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: frmcmp_batch returned rc=$rc but output exists: $output_file. Treating as success." >> "$log_file"
        fi
        return 0
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] FAILED: $file_name type=$module_type rc=$rc output=$output_file log=$log_file"
    return 1
}

run_group() {
    local label="$1"
    local extension="$2"
    local module_type="$3"
    local output_extension="$4"

    local files=()
    local f file_name output_file
    local total running_jobs submitted failures_file

    shopt -s nullglob
    files=( "$forms_source_dir"/*."$extension" )
    shopt -u nullglob

    total="${#files[@]}"
    running_jobs=0
    submitted=0
    failures_file="$(mktemp "/tmp/compile_${label}_failures.XXXXXX")"

    echo
    echo "======================================================================"
    echo "Compiling $label files"
    echo "Total: $total"
    echo "Parallel jobs: $parallel_jobs"
    echo "======================================================================"

    if (( total == 0 )); then
        echo "No $label files found"
        rm -f "$failures_file"
        return 0
    fi

    if (( start_index >= total )); then
        echo "start_index=$start_index is >= number of $label files ($total), skipping $label"
        rm -f "$failures_file"
        return 0
    fi

    for (( i=start_index; i<total; i++ )); do
        f="${files[i]}"
        file_name="${f##*/}"
        output_file="${file_name%.*}.${output_extension}"

        echo "Queueing $label item $(( i + 1 )) of $total: $file_name"

        (
            compile_one "$file_name" "$module_type" "$output_file"
            rc=$?
            if (( rc != 0 )); then
                echo "$label:$file_name:$rc:$log_dir/${file_name}.log" >> "$failures_file"
            fi
            exit "$rc"
        ) &

        (( running_jobs++ ))
        (( submitted++ ))

        if (( running_jobs >= parallel_jobs )); then
            wait -n || true
            (( running_jobs-- ))
        fi

        if (( batch_size > 0 && submitted % batch_size == 0 && i < total - 1 )); then
            echo "Submitted $submitted $label files. Waiting for current jobs before batch sleep..."
            while (( running_jobs > 0 )); do
                wait -n || true
                (( running_jobs-- ))
            done
            echo "Sleeping $batch_sleep seconds before next $label batch..."
            sleep "$batch_sleep"
        fi
    done

    echo "Waiting for remaining $label jobs..."
    while (( running_jobs > 0 )); do
        wait -n || true
        (( running_jobs-- ))
    done

    if [[ -s "$failures_file" ]]; then
        echo
        echo "FAILED $label compilations:"
        cat "$failures_file"
        cat "$failures_file" >> "$all_failures_file"
        rm -f "$failures_file"
        return 1
    fi

    echo "All $label compilations succeeded"
    rm -f "$failures_file"
    return 0
}

overall_rc=0

echo "Forms source directory: $forms_source_dir"
echo "FORMS_PATH: $FORMS_PATH"
echo "Log directory: $log_dir"
echo "Parallel jobs: $parallel_jobs"
echo "Batch size: $batch_size"

# Compile libraries first, then menus, then forms. Each physical source file is compiled once.
run_group "PLL" "pll" "LIBRARY" "plx" || overall_rc=1

if compgen -G "$forms_source_dir/*.mmb" >/dev/null || compgen -G "$forms_source_dir/*.fmb" >/dev/null; then
    echo "Sleeping $sleep_between_file_types seconds after PLL group..."
    sleep "$sleep_between_file_types"
fi

run_group "MMB" "mmb" "MENU" "mmx" || overall_rc=1

if compgen -G "$forms_source_dir/*.fmb" >/dev/null; then
    echo "Sleeping $sleep_between_file_types seconds after MMB group..."
    sleep "$sleep_between_file_types"
fi

run_group "FMB" "fmb" "FORM" "fmx" || overall_rc=1

echo
echo "======================================================================"
echo "Compilation summary"
echo "======================================================================"

if [[ -s "$all_failures_file" ]]; then
    echo "Some compilations failed:"
    cat "$all_failures_file"
    rm -f "$all_failures_file"
    exit 1
fi

rm -f "$all_failures_file"

if (( overall_rc != 0 )); then
    echo "Some compilations failed"
    exit "$overall_rc"
fi

echo "All compilations finished successfully"
exit 0
