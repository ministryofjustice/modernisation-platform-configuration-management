#!/bin/bash

# Determine if an RMAN Catalog Upgrade is required

. ~/.bash_profile

PATH=$PATH:/usr/local/bin
ORAENV_ASK=NO
ORACLE_SID=${CATALOG_DB}
. oraenv > /dev/null 2>&1

CATALOG_PASSWORD=$(aws secretsmanager get-secret-value --secret-id /oracle/database/${CATALOG_DB}/shared-passwords --query SecretString --output text | jq -r .rcvcatowner)

rman <<EORMAN
connect catalog rcvcatowner/${CATALOG_PASSWORD}
exit;
EORMAN