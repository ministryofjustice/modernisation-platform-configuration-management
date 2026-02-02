{% raw %}
#!/usr/bin/env bash
item=0
forms_source_files=$(ls /u01/tag/FormsSources/*.{fmb,pll,mmb} 2>/dev/null | xargs -n1 basename | sed 's/\.[^.]*$//')
forms_to_compile=()
sleep_time=15

for arg in "$@"
do
        case $arg in
                u=*)
                u="${arg#*=}"
                ;;
                p=*)
                p="${arg#*=}"
                ;;
                t=*)
                t="${arg#*=}"
                ;;
        esac
done

if [[ -z "$u" || -z "$p" || -z "$t" ]]; then
	echo "Error: Missing required arguments, ensure u, p and t arguments are set"
	exit 1
fi

for forms_source_file in $forms_source_files; do
	  filename=${forms_source_file#/u01/tag/FormsSources/}
	  base_filename="${filename%.*}"
	  if [[ ! " ${forms_to_compile[@]} " =~ " $base_filename " ]]; then
		  forms_to_compile+=("$base_filename")
	  fi
done

total_forms_to_compile=${#forms_to_compile[@]}
echo "Total number of forms to compile: ${#forms_to_compile[@]}"

for form_to_compile in "${forms_to_compile[@]}"; do
	((item++))
	echo "Attempting to process item number $item of $total_forms_to_compile - form name is: $form_to_compile"
	compform.sh -f $form_to_compile -c $u/$p@$t
	rc=$?
	if (( rc == 0 )); then
		echo "Successfully processed $form_to_compile"
	else
		echo "$form_to_compile returned non-zero exit code $rc, sleeping for $sleep_time before retrying..."
		sleep "$sleep_time"
		compform.sh -f $form_to_compile -c $u/$p@$t
		rc_2=$?
		if (( rc_2 == 0 )); then
			echo "Successfully processed $form_to_compile"
		else
			sleep_time_2=$(( $sleep_time * 2))
			echo "$form_to_compile returned non-zero exit code $rc_2 on second execution, sleeping for $sleep_time_2"
			sleep "$sleep_time_2"
			compform.sh -f $form_to_compile -c $u/$p@$t
			rc_3=$?
			if (( rc_3 == 0 )); then
				echo "Successfully processed $form_to_compile"
			else
				echo "$form_to_compile returned non-zero exit code $rc_3 on third execution, exiting..."
				exit 1
			fi
		fi
	fi
done
{% endraw %}