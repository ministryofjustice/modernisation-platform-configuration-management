#!/bin/bash

. ~/.bash_profile

WALLET=/u01/app/oracle/wallets/alfresco_wallet

function get_epoch() {
  CERT_TYPE=${1}
  DN=$(orapki wallet display -wallet ${WALLET} -summary | grep -iA1 "${CERT_TYPE} Certificates:" | tail -n1 | awk -F: '{gsub(/^[ \t]+/,"",$2); print $2}')
  orapki wallet export -wallet ${WALLET} -dn "${DN}" -cert /tmp/${CERT_TYPE}.crt > /dev/null 2>&1
  if [[ $? -eq 0 ]]
  then
    CERT_VALID_UNTIL_DATE=$(orapki cert display -cert /tmp/${CERT_TYPE}.crt | grep "Valid Until:" | awk -F'Valid Until:' '{gsub(/^[ \t]+/,"",$2); print $2}')
    EPOCH_DATE=$(date "+%s" -d "${CERT_VALID_UNTIL_DATE}")
  else
    echo "ERROR: Exporting certificate"
    exit 1
  fi
}

get_epoch trusted
EPOCH_TRUSTED_CERT=${EPOCH_DATE}
NO_OF_DAYS_BEFORE_TRUSTED_EXPIRY=$(( (${EPOCH_TRUSTED_CERT} - $(date +%s)) / (60*60*24) ))

echo "${NO_OF_DAYS_BEFORE_TRUSTED_EXPIRY}"