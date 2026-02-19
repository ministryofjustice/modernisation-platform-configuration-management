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
        u=*) u="${arg#*=}" ;;
        p=*) p="${arg#*=}" ;;
        s=*) start_index="${arg#*=}" ;;
        t=*) t="${arg#*=}" ;;
    esac
done

if [[ -z "$u" || -z "$p" || -z "$t" ]]; then
    echo "Error: Missing required arguments u, p, or t"
    exit 1
fi

if ! [[ "$start_index" =~ ^[0-9]+$ ]]; then
    echo "Error: start index (s=) must be a non-negative integer"
    exit 1
fi

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

retry_compile() {
    local form="$1"
    local attempt=1
    local sleep_time=$sleep_between_unsuccessful_compilations

    while (( attempt <= max_attempts )); do
        compform.sh -f "$form" -c "$u/$p@$t"
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
    retry_compile "$form"
    echo "Successfully processed $form"
    sleep "$sleep_between_successful_compilations"

    if (( item % batch_size == 0 && item < total_forms )); then
        echo "Processed $item forms, sleeping $batch_sleep seconds before next batch..."
        sleep "$batch_sleep"
    fi
done
{% endraw %}