{% raw %}
#!/usr/bin/env bash
batch_size=0
batch_sleep=0
sleep_between_successful_compilations=1
sleep_between_unsuccessful_compilations=120
sleep_between_file_types=20
max_attempts=6
start_index=0
parallel_jobs=2

fmb_files=(/u01/tag/FormsSources/*.fmb)
mmb_files=(/u01/tag/FormsSources/*.mmb)
pll_files=(/u01/tag/FormsSources/*.pll)

forms_to_compile=()

for arg in "$@"; do
    case $arg in
        batch_size=*) batch_size="${arg#*=}" ;;
        batch_sleep=*) batch_sleep="${arg#*=}" ;;
        max_attempts=*) max_attempts="${arg#*=}" ;;
        parallel_jobs=*) parallel_jobs="${arg#*=}" ;;
        password=*) password="${arg#*=}" ;;
        start_index=*) start_index="${arg#*=}" ;;
        sleep_between_successful_compilations=*) sleep_between_successful_compilations="${arg#*=}" ;;
        sleep_between_unsuccessful_compilations=*) sleep_between_unsuccessful_compilations="${arg#*=}" ;;
        sleep_between_file_types=*) sleep_between_file_types="${arg#*=}" ;;
        target_db=*) target_db="${arg#*=}" ;;
        username=*) username="${arg#*=}" ;;
    esac
done

if [[ -z "$username" || -z "$password" || -z "$target_db" ]]; then
    echo "Error: Missing required arguments username, password, or target_db"
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

for var_name in start_index batch_size batch_sleep sleep_between_successful_compilations sleep_between_unsuccessful_compilations sleep_between_file_types max_attempts parallel_jobs; do
    validate_non_negative_integer "${!var_name}" "$var_name"
done

for f in "${pll_files[@]}" "${fmb_files[@]}" "${mmb_files[@]}"; do
    [[ -e "$f" ]] || continue
    base="${f##*/}"
    base="${base%.*}"
    [[ " ${forms_to_compile[*]} " =~ " $base " ]] || forms_to_compile+=("$base")
done

total_forms=${#forms_to_compile[@]}
echo "Total forms to compile: $total_forms"
echo "Starting at index: $start_index"
echo "Parallel jobs: $parallel_jobs"

if (( start_index >= total_forms )); then
    echo "Start index ($start_index) >= total forms ($total_forms). Nothing to do."
    exit 0
fi

progress_file="/tmp/compile_progress.txt"
echo 0 > "$progress_file"
lock_file="/tmp/compile_progress.lock"

compile_form() {
    local form="$1"
    local attempt=1
    local sleep_time=$sleep_between_unsuccessful_compilations

    while (( attempt <= max_attempts )); do
        compform.sh -f "$form" -c "$username/$password@$target_db"
        rc=$?
        (( rc == 0 )) && return 0

        if (( attempt == max_attempts )); then
            echo "$form failed after $max_attempts attempts, exiting..."
            return 1
        fi

        echo "$form failed (attempt $attempt, rc=$rc). Sleeping $sleep_time seconds..."
        sleep "$sleep_time"
        sleep_time=$(( sleep_time * 2 ))
        ((attempt++))
    done
}

compile_chunk() {
    local chunk=("$@")
    local previous_type=""

    for form in "${chunk[@]}"; do
        if [[ -f "/u01/tag/FormsSources/$form.pll" ]]; then
            current_type="PLL"
        elif [[ -f "/u01/tag/FormsSources/$form.mmb" ]]; then
            current_type="MMB"
        else
            current_type="FMB"
        fi

        if [[ -n "$previous_type" && "$current_type" != "$previous_type" ]]; then
            echo "[Worker $$] Finished all $previous_type files in this chunk, sleeping $sleep_between_file_types seconds..."
            sleep "$sleep_between_file_types"
        fi
        previous_type="$current_type"

        echo "[Worker $$] Compiling $form"
        compile_form "$form" || return 1

        {
            flock 200
            count=$(< "$progress_file")
            count=$((count + 1))
            echo "$count" > "$progress_file"
            echo "[Worker $$] $form compiled successfully ($count of $total_forms)"
        } 200>"$lock_file"

        sleep "$sleep_between_successful_compilations"
    done
}

chunk_size=$(( (total_forms - start_index + parallel_jobs - 1) / parallel_jobs ))
pids=()

for ((i=start_index; i<total_forms; i+=chunk_size)); do
    chunk=( "${forms_to_compile[@]:i:chunk_size}" )
    compile_chunk "${chunk[@]}" &
    pids+=($!)
done

for pid in "${pids[@]}"; do
    wait "$pid" || { echo "Compilation failed"; exit 1; }
done

echo "All compilations finished"
rm -f "$progress_file" "$lock_file"
{% endraw %}