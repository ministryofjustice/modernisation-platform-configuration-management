#!/bin/bash

set -euo pipefail

# Install JSON for Nomis API 


cd /u02/stage/${db_name}/nomis_api/nomis_api/Database/

#:wqexport OMS_OWNER_PWD=$(aws secretsmanager get-secret-value --secret-id "/oracle/database/${ORACLE_SID}/passwords" --query SecretString --output text | jq -r '.oms_owner')


# Run SQL script
sql_log_file=$(mktemp)

if ! sqlplus -s / as sysdba <<EOF | tee "$sql_log_file"



WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR CONTINUE

@INSTALL_pljson_v3.sql

EXIT

EOF
then
	echo "sqlplus failed due to an OS-level error"
	rm -f "$sql_log_file"
	exit 1
fi

# Allow reruns where objects already exist (ORA-02303), but fail for any other SQL/SQL*Plus error.
unexpected_errors=$(grep -E 'ORA-|SP2-' "$sql_log_file" | grep -Ev 'ORA-02303' || true)
rm -f "$sql_log_file"

if [[ -n "$unexpected_errors" ]]; then
	echo "Unexpected SQL errors detected during PLJSON installation:"
	echo "$unexpected_errors"
	exit 1
fi

echo "PLJSON installation completed successfully"

