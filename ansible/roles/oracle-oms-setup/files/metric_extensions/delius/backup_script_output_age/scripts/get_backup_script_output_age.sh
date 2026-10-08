#!/usr/bin/env bash
# Run on each database host to report the age of the latest RMAN backup script
# output for each locally configured primary database. Missing or stale output
# suggests that scheduled backups may not be running; output alone does not
# confirm that a backup succeeded.
#
# Output: database|age_in_whole_days, using the file modification time.
# An age of 999 means no matching /tmp/rman*.out file was found. The caller decides
# which ages are too old for the expected backup schedule.
# Set DEBUG=1 to send diagnostic messages to stderr without changing stdout.
set -euo pipefail

debug() {
	if [[ "${DEBUG:-0}" == "1" ]]; then
		printf 'DEBUG: %s\n' "$*" >&2
	fi
}

debug "Discovering configured databases"
databases="$(srvctl config database)"
now="$(date +%s)"
# Expand the output-file pattern once; nullglob gives an empty array if absent.
shopt -s nullglob
backup_files=(/tmp/rman*.out)
debug "Found ${#backup_files[@]} candidate backup output files"

while IFS= read -r database; do
	[[ -n "$database" ]] || continue

	# Only primary databases are included in this backup-schedule check.
	role="$(srvctl config database -d "$database" | awk '/Database role/{print $NF}')"
	debug "Database $database has role $role"
	if [[ "$role" != "PRIMARY" ]]; then
		debug "Skipping non-primary database $database"
		continue
	fi

	latest_modified=""
	for backup_script_output_file in "${backup_files[@]}"; do
		if [[ ! -f "$backup_script_output_file" ]]; then
			debug "Skipping non-regular file $backup_script_output_file"
			continue
		fi
		debug "Checking $backup_script_output_file for database $database"
		# Ignore whitespace and log prefixes, but require an exact database name.
		if awk -v database="$database" '
			BEGIN {
				target = "Target Name = " database
				gsub(/[[:space:]]/, "", target)
			}
			{
				gsub(/[[:space:]]/, "")
				sub(/^.*TargetName=/, "TargetName=")
				if ($0 == target) {
					matched = 1
					exit
				}
			}
			END { exit !matched }
		' "$backup_script_output_file"; then
			# Try GNU stat first, then BSD stat; retain the newest matching file.
			modified="$(stat -c '%Y' -- "$backup_script_output_file" 2>/dev/null || stat -f '%m' "$backup_script_output_file")"
			debug "Matched $backup_script_output_file for $database; modification timestamp=$modified"
			if [[ -z "$latest_modified" ]] || (( modified > latest_modified )); then
				latest_modified="$modified"
				debug "Newest matching output for $database is $backup_script_output_file"
			fi
		else
			debug "No matching target for $database in $backup_script_output_file"
		fi
	done

	# Report elapsed whole days, or 999 when no matching output exists.
	age=999
	if [[ -n "$latest_modified" ]]; then
		age=$(( (now - latest_modified) / 86400 ))
	else
		debug "No matching backup output found for $database"
	fi
	debug "Database $database backup age=$age days"
	printf '%s|%s\n' "$database" "$age"
done <<< "$databases"
