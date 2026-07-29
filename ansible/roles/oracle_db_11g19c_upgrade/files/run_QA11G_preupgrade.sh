#!/bin/bash

# Gather Dictionary and Fixed Object Statistics

# We need to explicitly exclude the SYS.HIST_AUD$ table if it exists in this database
# because it is huge and gathering statistics on it will take many hours.
sqlplus -s / as sysdba <<EOSQL

WHENEVER SQLERROR EXIT FAILURE

ALTER SYSTEM SET db_recovery_file_dest_size='50G' SCOPE=spfile;

ALTER SYSTEM SET processes=300 SCOPE=spfile;

ALTER SYSTEM RESET sec_case_sensitive_logon SCOPE=SPFILE;

EXIT

EOSQL
