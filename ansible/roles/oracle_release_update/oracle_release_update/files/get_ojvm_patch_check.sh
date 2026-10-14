#!/bin/bash

# Check if OJVM Patch has been installed

export PATCHID=$1

. ~/.bash_profile

sqlplus -s /  as sysdba <<EOF
SET LINES 1000
SET PAGES 0
SET FEEDBACK OFF
SET HEADING OFF
WHENEVER SQLERROR EXIT FAILURE
SELECT
    coalesce(MAX(status), 'ABSENT_OR_FAILURE') installed
FROM
    dba_registry_sqlpatch
WHERE
        patch_id = ${PATCHID}
    AND action = 'APPLY'
    AND status = 'SUCCESS';
EXIT
EOF
