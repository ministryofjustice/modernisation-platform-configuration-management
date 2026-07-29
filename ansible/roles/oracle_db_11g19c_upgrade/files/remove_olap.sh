#!/bin/bash

#  Remove OLAP      

output_file=$(mktemp)

sqlplus -s / as sysdba >"$output_file" 2>&1 <<EOSQL

WHENEVER SQLERROR EXIT FAILURE

@/u01/app/oracle/product/11.2.0.4/db_1/olap/admin/catnoamd.sql


EXIT

EOSQL

exit_code=$?
cat "$output_file"

if [ "$exit_code" -ne 0 ]; then
	other_ora_count=$(awk '/ORA-[0-9]{5}:/{ if ($0 !~ /ORA-01432: public synonym to be dropped does not exist/) count++ } END { print count + 0 }' "$output_file")
	if grep -q 'ORA-01432: public synonym to be dropped does not exist' "$output_file" && [ "$other_ora_count" -eq 0 ]; then
		rm -f "$output_file"
		exit 0
	fi
fi

rm -f "$output_file"
exit "$exit_code"
