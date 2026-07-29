#!/bin/bash

#  Upgrade Oracle Application Express (APEX) manually before the database upgrade, we've droped it and reinstalled it.
      
# The database contains APEX version 3.2.1.00.12. Upgrade APEX to at least version 18.2.0.00.12.      
# Starting with Oracle Database Release 18, APEX is not upgraded automatically as part of the database upgrade. 
# Refer to My Oracle Support Note 1088970.1 for information about APEX installation and upgrades.

cd /u02/stage/${db_name}/nomis_api/

unzip nomis_api.zip

export OMS_OWNER_PWD=$(aws secretsmanager get-secret-value --secret-id "/oracle/database/{{ db_name }}/passwords" --query SecretString --output text | jq -r '.oms_owner')


# Run SQL script
sqlplus -s "oms_owner/${OMS_OWNER_PWD}@${ORACLE_SID}" <<EOF

WHENEVER SQLERROR EXIT FAILURE

@INSTALL_pljson_v3.sql

EXIT

EOF

echo "PLJSON installation completed successfully"


