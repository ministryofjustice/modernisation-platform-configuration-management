#!/bin/bash
#
# Test that we can successfully backup from a standby database

. ~/.bash_profile

if [[ $(srvctl config database -d ${ORACLE_SID} | grep "Database role:" | cut -f3 -d ' ') != PHYSICAL_STANDBY ]];
then
   # Not a standby database - nothing to do
   exit 0
fi

function get_rman_password(){
  ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
  ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/EC2OracleEnterpriseManagementSecretsRole"
  SESSION="catalog-ansible"
  SECRET_ACCOUNT_ID=$(aws ssm get-parameters --with-decryption --name account_ids | jq -r .Parameters[].Value |  jq -r 'with_entries(if (.key|test("hmpps-oem.*$")) then ( {key: .key, value: .value}) else empty end)' | jq -r 'to_entries|.[0].value' )
  CREDS=$(aws sts assume-role --role-arn "${ROLE_ARN}" --role-session-name "${SESSION}"  --output text --query "Credentials.[AccessKeyId,SecretAccessKey,SessionToken]")
  export AWS_ACCESS_KEY_ID=$(echo "${CREDS}" | tail -1 | cut -f1)
  export AWS_SECRET_ACCESS_KEY=$(echo "${CREDS}" | tail -1 | cut -f2)
  export AWS_SESSION_TOKEN=$(echo "${CREDS}" | tail -1 | cut -f3)
  SECRET_ARN="arn:aws:secretsmanager:eu-west-2:${SECRET_ACCOUNT_ID}:secret:/oracle/database/${CATALOG_DB}/shared-passwords"
  RMANUSER=${CATALOG_SCHEMA:-rcvcatowner}
  RMANPASS=$(aws secretsmanager get-secret-value --secret-id "${SECRET_ARN}" --query SecretString --output text | jq -r .rcvcatowner)
  unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
}

# We assume only one RMAN catalog is defined in the tnsnames.ora file, and that is the one used by this database
CATALOG_DB=$(grep -E "^.*RCVCAT[[:space:]]+=" ${ORACLE_HOME}/network/admin/tnsnames.ora | cut -f1 -d ' ')
get_rman_password

# For test purposes we will backup the smallest file in the database. We are not looking to create an actual backup;
# simply verify that a backup can be successfully run.
SMALLEST_FILE=$(echo -e "report schema;" | rman target / | grep DATAFILE | sort -n -k2 | head -1 | cut -d' ' -f 1)


BACKUP_TEST=$(
cat <<EORMAN | rman target /
connect catalog rcvcatowner/${RMANPASS}@${CATALOG_DB}
run {
allocate channel c1 device type sbt
  parms='SBT_LIBRARY=${ORACLE_HOME}/lib/libosbws.so,
  ENV=(OSB_WS_PFILE=${ORACLE_HOME}/dbs/osbws.ora)';
backup validate datafile ${SMALLEST_FILE};
release channel c1;
}
exit
EORMAN
)
RC=$?
ORA_COUNT=$(echo "${BACKUP_TEST}" | grep -c ORA-)
ERR_COUNT=$(echo "${BACKUP_TEST}" | grep -ci ERROR)
ORA_MESSAGE=$(echo "${BACKUP_TEST}" | grep ORA- | xargs)
ERR_MESSAGE=$(echo "${BACKUP_TEST}" | grep -i ERROR | xargs)

echo "$RC|${ORA_COUNT}|${ERR_COUNT}|${ORA_MESSAGE}|${ERR_MESSAGE}"