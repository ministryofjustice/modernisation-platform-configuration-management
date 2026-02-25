{% raw %}
#!/usr/bin/env bash
batch_size=20
batch_sleep=10
sleep_between_successful_compilations=2
sleep_between_unsuccessful_compilations=60
max_attempts=4
start_index=0

fmb_files=(/u01/tag/FormsSources/*.fmb)
mmb_files=(/u01/tag/FormsSources/*.mmb)
pll_files=(/u01/tag/FormsSources/*.pll)

forms_to_compile=()

for arg in "$@"; do
    case $arg in
        batch_size=*) batch_size="${arg#*=}" ;;
        batch_sleep=*) batch_sleep="${arg#*=}" ;;
        max_attempts=*) max_attempts="${arg#*=}" ;;
        password=*) password="${arg#*=}" ;;
        start_index=*) start_index="${arg#*=}" ;;
        sleep_between_successful_compilations=*) sleep_between_successful_compilations="${arg#*=}" ;;
        sleep_between_unsuccessful_compilations=*) sleep_between_unsuccessful_compilations="${arg#*=}" ;;
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

for var_name in start_index batch_size batch_sleep sleep_between_successful_compilations sleep_between_unsuccessful_compilations max_attempts; do
    validate_non_negative_integer "${!var_name}" "$var_name"
done

for f in "${pll_files[@]}" "${mmb_files[@]}" "${fmb_files[@]}"; do
    [[ -e "$f" ]] || continue
    base="${f##*/}"
    base="${base%.*}"
    [[ " ${forms_to_compile[*]} " =~ " $base " ]] || forms_to_compile+=("$base")
done

total_forms=${#forms_to_compile[@]}
echo "Total forms to compile: $total_forms"
echo "Starting at index: $start_index"

if (( start_index >= total_forms )); then
    echo "Start index ($start_index) >= total forms ($total_forms). Nothing to do."
    exit 0
fi

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
            exit 1
        fi

        echo "$form failed (attempt $attempt, rc=$rc). Sleeping $sleep_time seconds..."
        sleep "$sleep_time"
        sleep_time=$(( sleep_time * 2 ))
        ((attempt++))
    done
}

for (( i=start_index; i<total_forms; i++ )); do
    form="${forms_to_compile[i]}"
    item=$(( i + 1 ))
    echo "Processing item $item of $total_forms - form: $form"
    compile_form "$form"
    echo "Successfully processed $form"
    sleep "$sleep_between_successful_compilations"

    if (( item % batch_size == 0 && item < total_forms )); then
        echo "Processed $item forms, sleeping $batch_sleep seconds before next batch..."
        sleep "$batch_sleep"
    fi
done
{% endraw %}