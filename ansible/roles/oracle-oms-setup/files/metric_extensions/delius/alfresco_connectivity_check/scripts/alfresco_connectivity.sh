#!/bin/bash
#
#  Although Alfresco availability is monitored directly, there may be reasons that the database
#  itself cannot connect - for example incorrect wallet location or contents, or blocking access
#  control list.   This ME checks that the database can at least connect to Alfresco although it
#  does not make any attempt to retrieve valid data.

. ~/.bash_profile


# Function to retrieve passwords from AWS Secrets Manager
get_password() {
  USERNAME=$1
  if [[ "${ORACLE_SID}" == "EMREP" || "${ORACLE_SID}" == *RCVCAT* ]]; then
    aws secretsmanager get-secret-value --secret-id "/oracle/database/${ORACLE_SID}/passwords" --region eu-west-2 --query SecretString --output text | jq -r .${USERNAME}
  else
    INSTANCEID=$(wget -q -O - http://169.254.169.254/latest/meta-data/instance-id)
    APPLICATION=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCEID}" "Name=key,Values=application" --query "Tags[].Value" --output text)
    if [[ "${APPLICATION}" == "delius" ]]; then
      DELIUS_ENVIRONMENT=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCEID}" "Name=key,Values=delius-environment" --query "Tags[].Value" --output text)
      SECRET_ID="delius-core-${DELIUS_ENVIRONMENT}-oracle-db-dba-passwords"
    elif [ "$APPLICATION" = "delius-mis" ]
    then
      DELIUS_ENVIRONMENT=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCEID}" "Name=key,Values=delius-environment" --query "Tags[].Value" --output text)
      DATABASE_TYPE=$(aws ec2 describe-tags --filters "Name=resource-id,Values=${INSTANCEID}" "Name=key,Values=database" --query 'Tags[].Value' --output text | cut -d'_' -f1)
      SECRET_ID="delius-mis-${DELIUS_ENVIRONMENT}-oracle-${DATABASE_TYPE}-db-dba-passwords"
    else
      # Try the format used for nomis and oasys
      SECRET_ID="/oracle/database/$2/passwords"
    fi
    PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${SECRET_ID} --region eu-west-2 --query SecretString --output text 2>/dev/null | jq -r .${USERNAME})
    echo "${PASSWORD}"
  fi
}

oratab=/etc/oratab

# Only one database should be running on the Delius host
export ORACLE_SID=$(grep -v '^#' $oratab | grep -v AGENT | grep -v -i listener | grep -v -i asm | cut -d ":" -f1 | awk 'NF' | head -1) 
 
ohome=`cat $oratab | grep $ORACLE_SID | grep -v '^#' | grep -v AGENT | grep -v -i listener | grep -v -i asm | cut -d ":" -f2`;
 
ORACLE_HOME=${ohome}; export ORACLE_HOME;
 
export ORAENV_ASK=NO
. oraenv > /dev/null

# Exit without failure if database is not up
if [[ $(srvctl config database -d ${ORACLE_SID} | awk -F: '/Start options/{print $2}' | tr -d ' ') == mount ]];
then
    # Ignore this metric on mounted (not open) databases
    exit 0
fi

# Retrieve DBSNMP password
DBSNMP_PASSWORD=$(get_password dbsnmp $ORACLE_SID)
if [[ -n "$DBSNMP_PASSWORD" && "$DBSNMP_PASSWORD" != "null" ]]; then
  CONNECTION_STRING="dbsnmp/${DBSNMP_PASSWORD}"
else
  CONNECTION_STRING="/ as sysdba"
fi

# Check if the table exists (it will not if this database is not running replication)
table_exists=$(sqlplus -S "$CONNECTION_STRING" <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM dba_tables WHERE owner='DELIUS_APP_SCHEMA' AND table_name = 'SPG_CONTROL';
EXIT;
EOF
)

# Trim any leading/trailing whitespace.
table_exists=$(echo "$table_exists" | xargs)

# If the count is zero, the table does not exist.  Do not treat this as an error
# as it may be intentional.
if [ "$table_exists" -eq 0 ]; then
    exit 0
fi

# Connect as sys as dbsnmp does not have permissions to call the url
sqlplus -s / as sysdba <<EOF
WHENEVER SQLERROR EXIT FAILURE;
SET FEEDBACK OFF
SET HEADING OFF
SET SERVEROUT ON
SET NEWPAGE 0
SET PAGESIZE 0
SET LINES 2000

ALTER SESSION SET CURRENT_SCHEMA=delius_app_schema;

SET SERVEROUT ON

DECLARE
    l_url             spg_control.value_string%TYPE;
    l_wallet_location spg_control.value_string%TYPE;
    l_http_request    utl_http.req;
    l_http_response   utl_http.resp;
    l_text            VARCHAR2(32767);
BEGIN
    SELECT
        value_string
    INTO l_wallet_location
    FROM
        spg_control
    WHERE
        control_code = 'ALFWALLET';

    utl_http.set_wallet(l_wallet_location, NULL);
    SELECT
        value_string
    INTO l_url
    FROM
        spg_control
    WHERE
        control_code = 'ALFURL';

                  -- Make a HTTP request and get the response.
    l_http_request := utl_http.begin_request(l_url);
    l_http_response := utl_http.get_response(l_http_request);
    utl_http.end_response(l_http_response);

                  -- If we get here then connectivity is available
                  -- (We are only checking connectivity - not fetching a valid web
                  --  page so a response code of 404 is valid).
    dbms_output.put_line('SUCCESS|HTTP Response Code: ' || l_http_response.status_code);
EXCEPTION
    WHEN OTHERS THEN
        utl_http.end_response(l_http_response);
        dbms_output.put_line(SUBSTR(translate('FAIL|' || dbms_utility.format_error_stack, '|'
                                                                                   || chr(10)
                                                                                   || chr(13), '|  '),1,1000));

END;
/
EOF