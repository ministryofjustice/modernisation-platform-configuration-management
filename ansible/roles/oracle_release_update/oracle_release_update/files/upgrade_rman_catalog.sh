#!/bin/bash
# Upgrade RMAN Catalog non interactively
# (Note that no other sessions should be open to the Catalog at this time or the upgrade will fail)

. ~/.bash_profile

PATH=$PATH:/usr/local/bin
ORAENV_ASK=NO
ORACLE_SID=${CATALOG_DB}
. oraenv > /dev/null 2>&1

RMAN_USER=rcvcatowner
CATALOG_PASSWORD=$(aws secretsmanager get-secret-value --secret-id /oracle/database/${CATALOG_DB}/shared-passwords --query SecretString --output text | jq -r .${RMAN_USER})

# Temporarily change the RMAN password to block concurrent connections
CATALOG_TEMP_PASSWORD=p#$(oepnssl rand -base64 12)

sqlplus <<EOSQL
connect / as sysdba
WHENEVER SQLERROR EXIT FAILURE;
ALTER USER ${RMAN_USER} IDENTIFIED BY ${CATALOG_TEMP_PASSWORD} ACCOUNT UNLOCK;
EXIT
EOSQL

# Bounce the database to ensure existing concurrent connections are removed
srvctl stop database -d ${ORACLE_SID}
srvctl start database -d ${ORACLE_SID}

# Upgrade the catalog
rman <<EORMAN
connect catalog ${RMAN_USER}/${CATALOG_TEMP_PASSWORD}
upgrade catalog noprompt;
exit;
EORMAN

# Reset the password to its original value to allow concurrent connections
sqlplus <<EOSQL
connect / as sysdba
WHENEVER SQLERROR EXIT FAILURE;
ALTER USER ${RMAN_USER} IDENTIFIED BY ${CATALOG_PASSWORD} ACCOUNT UNLOCK;
EXIT
EOSQL
