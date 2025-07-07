#!/bin/bash
#
#  This script highlights any parameters which differ between primary and standby instances.
#  It is only intended to run from the primary instance.   No parameters are required.
#  Note that some parameters are "normalised" by removing references to server names etc.
#  to avoid spurious mismatches between databases which are expected.

. ~/.bash_profile


# If run on an instance hosting OEM we need to explicitly set up the database environment
if grep "^EMREP:" /etc/oratab > /dev/null; then
        export ORAENV_ASK=NO
        export ORACLE_SID=EMREP
        . oraenv >/dev/null
fi

function get_password()
{
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
    #echo "Using secret ${SECRET_ID} to retrieve password for ${USERNAME}"
    PASSWORD=$(aws secretsmanager get-secret-value --secret-id ${SECRET_ID} --region eu-west-2 --query SecretString --output text 2>/dev/null | jq -r .${USERNAME})
    echo "${PASSWORD}"
  fi
}

function get_jdbc()
{
DATABASE=$1
tnsping ${DATABASE} | grep "Attempting" | sed -r 's/(.*)HOST\s+=\s+(.*)\)\(PORT\s+=\s+([0-9]+).*\(SERVICE_NAME\s+=\s+(\w*)\)+$/\2:\3\/\4/'
}


function report_differences()
{
PRIMARY_DATABASE=$1
STANDBY_DATABASE=$2

JDBC_CONNECT=$(get_jdbc ${STANDBY_DATABASE})

sql -S /nolog <<EOSQL | sed -r '/^\s*$/d'
SET HEAD OFF
SET FEED OFF
SET PAGES 0

connect dbsnmp/${DBSNMP_PASSWORD}

CREATE PRIVATE TEMPORARY TABLE ora\$ptt_standby_parameter (
 name      VARCHAR2(80)
,value     VARCHAR2(4000)
,isdefault VARCHAR2(9))
ON COMMIT PRESERVE DEFINITION;

COPY FROM jdbc:oracle:thin:sys/${SYS_PASSWORD}@${JDBC_CONNECT}?internal_logon=sysdba INSERT ora\$ptt_standby_parameter USING SELECT name,value,isdefault FROM   v\$system_parameter;

CREATE PRIVATE TEMPORARY TABLE ora\$ptt_standby_database (
 open_mode     VARCHAR2(20)
,database_role VARCHAR2(16))
ON COMMIT PRESERVE DEFINITION;

COPY FROM jdbc:oracle:thin:sys/${SYS_PASSWORD}@${JDBC_CONNECT}?internal_logon=sysdba INSERT ora\$ptt_standby_database USING SELECT open_mode,database_role FROM   v\$database;

WITH parameter_values AS (
    SELECT
        i.instance_name,
        p.name,
        p.value,
        p.isdefault,
        d.database_role,
        d.open_mode
    FROM
             v\$instance i
        CROSS JOIN v\$system_parameter p
        CROSS JOIN v\$database  d
    UNION ALL
    SELECT
        '${STANDBY_DATABASE}' instance_name,
        p.name,
        p.value,
        p.isdefault,
        d.database_role,
        d.open_mode
    FROM
             ora\$ptt_standby_parameter p
        CROSS JOIN ora\$ptt_standby_database d
), normalized_parameter_values AS (
    SELECT
        a.instance_name,
        a.name,
        regexp_replace(
            CASE
                WHEN a.name IN('db_unique_name', 'fal_client', 'instance_name') THEN
                    regexp_replace(a.value, '^'
                                            || a.instance_name
                                            || '$', '<<SID>>', 1, 0,
                                   'i')
                WHEN a.name IN('background_dump_dest', 'core_dump_dest', 'user_dump_dest') THEN
                    regexp_replace((regexp_replace(a.value, '/'
                                                            || a.instance_name
                                                            || '/', '/<<SID>>/', 1, 0,
                                                   'i')),
                                   '/'
                                   || a.instance_name
                                   || '/',
                                   '/<<SID>>/',
                                   1,
                                   0,
                                   'i')
                WHEN a.name IN('audit_file_dest', 'dg_broker_config_file1', 'dg_broker_config_file2') THEN
                    regexp_replace(a.value, '/'
                                            || a.instance_name
                                            || '/', '/<<SID>>/', 1, 0,
                                   'i')
                WHEN a.name IN('control_files') THEN
                    regexp_replace(regexp_replace(lower(a.value),
                                                  '/'
                                                  || a.instance_name
                                                  || '/',
                                                  '/<<SID>>/',
                                                  1,
                                                  0,
                                                  'i'),
                                   '\d+',
                                   '0')
                WHEN a.name IN('local_listener') THEN
                    regexp_replace(a.value, '\(HOST=\d+\.\d+\.\d+\.\d+\)', '(HOST=xx.xx.xx.xx)')
                WHEN a.name IN('log_archive_dest_1') THEN
                    (
                        SELECT
                            LISTAGG(dest_desc, ',') WITHIN GROUP(
                            ORDER BY
                                dest_desc
                            )
                        FROM
                            (
                                SELECT
                                    instance_name,
                                    upper(regexp_substr(lad1, '[^ ]+', 1, level)) dest_desc
                                FROM
                                    (
                                        SELECT
                                            instance_name,
                                            regexp_replace(replace(regexp_replace(z.value, 'db_unique_name='
                                                                                           || z.instance_name
                                                                                           || '(,|$)', 'db_unique_name=<<SID>>', 1, 0
                                                                                           ,
                                                                                  'i'),
                                                                   ', ',
                                                                   ','),
                                                           '\((\w+),\s+(\w+)\)',
                                                           '(\1,\2)') lad1
                                        FROM
                                            parameter_values z
                                        WHERE
                                                z.name = 'log_archive_dest_1'
                                            AND z.instance_name = a.instance_name
                                    )
                                CONNECT BY
                                    regexp_substr(lad1, '[^ ]+', 1, level) IS NOT NULL
                            )
                    )
                WHEN a.name IN('fal_server', 'log_archive_dest_2', 'log_archive_dest_3', 'service_names') THEN
                    '<<ignored>>'
                WHEN a.name IN('log_archive_dest_state_1', 'log_archive_dest_state_2', 'log_archive_dest_state_3', 'standby_file_management'
                , 'shadow_core_dump',
                               'plscope_settings') THEN
                    upper(a.value)
                WHEN a.name IN('db_file_multiblock_read_count', 'shared_pool_reserved_size')
                     AND a.isdefault = 'TRUE' THEN
                    'DEFAULT'
                WHEN a.name IN('log_archive_config') -- Make ordering consistent for values in log_archive_config
                 THEN
                    (
                        SELECT
                            LISTAGG(lower(tns_alias),
                                    ',') WITHIN GROUP(
                            ORDER BY
                                tns_alias
                            ) log_archive_config_value
                        FROM
                            (
                                SELECT
                                    regexp_substr(tns_alias, '[^,]+', 1, level) tns_alias
                                FROM
                                    (
                                        SELECT
                                            regexp_replace(value, '^.*\((.*)\)$', '\1') tns_alias
                                        FROM
                                            parameter_values z
                                        WHERE
                                                z.name = 'log_archive_config'
                                            AND z.instance_name = a.instance_name
                                    )
                                CONNECT BY
                                    regexp_substr(tns_alias, '[^,]+', 1, level) IS NOT NULL
                            )
                    )
                WHEN a.name IN('spfile') THEN
                    regexp_replace((regexp_replace(a.value, '/'
                                                            || a.instance_name
                                                            || '/', '/<<SID>>/', 1, 0,
                                                   'i')),
                                   'spfile'
                                   || a.instance_name
                                   || '.ora',
                                   'spfile<<SID>>.ora',
                                   1,
                                   0,
                                   'i')
                ELSE
                    value
            END,
            '^(.*)(\s+|,)(.*)$',
            '"'
            || '\1\2\3'
            || '"') normalized_value
    FROM
        parameter_values a
), primary_parameters AS (
    SELECT
        *
    FROM
        normalized_parameter_values b
    WHERE
        b.instance_name = '${PRIMARY_DATABASE}'
), standby_parameters AS (
    SELECT
        *
    FROM
        normalized_parameter_values b
    WHERE
        b.instance_name = '${STANDBY_DATABASE}'
), parameter_comparison AS (
    SELECT
        '${STANDBY_DATABASE}' instance_name,
        c.name,
        c.normalized_value primary_value,
        d.normalized_value standby_value,
        CASE
            WHEN ( c.normalized_value = d.normalized_value )
                 OR ( c.normalized_value IS NULL
                      AND d.normalized_value IS NULL ) THEN
                'Y'
            ELSE
                'N'
        END                parameter_match
    FROM
        primary_parameters c
        FULL OUTER JOIN standby_parameters d ON c.name = d.name
)
SELECT
     instance_name||'|'||
     name||'|'||
     SUBSTR(primary_value,0,20)||'|'|| -- OEM Console can't handle more than 20 characters
     SUBSTR(standby_value,0,20)
FROM
    parameter_comparison e
WHERE
    e.parameter_match != 'Y'
AND
    e.name != '_bug32914795_bct_last_dba_buffer_size' -- See MOS Note 3049433.1
AND
    e.name NOT LIKE '_dbmsum%'; -- exclude due to xml formatting issues


EXIT
EOSQL
}

# Function to identify all ORACLE_SID values on the host
get_oracle_sids() {
  grep -E '^[^+#]' /etc/oratab | awk -F: 'NF && $1 ~ /^[^ ]/ {print $1}'
}

# Main script execution
sids=$(get_oracle_sids)
if [ -z "$sids" ]; then
  # if no sids on this instance just exit
#  echo "No ORACLE_SID values found in /etc/oratab. Exiting."
  exit 0
fi

for sid in $sids; do
    # Get the connection string to use for this database
    #echo "Checking parameters for database: ${sid}"
    export ORACLE_SID=$sid
    export ORAENV_ASK=NO
    . oraenv >/dev/null 2>&1
    # We check that the ORACLE_SID is the primary database as we only want to run this check against the primary
    PRIMARY_SID=$(echo -e "show configuration;" | dgmgrl / | grep "Primary database" |  cut -d'-' -f1 | sed 's/ //g' | tr '[:upper:]' '[:lower:]')

    if [[ "${ORACLE_SID,,}" == "${PRIMARY_SID}" ]];
    then
        DBSNMP_PASSWORD=$(get_password dbsnmp)
        if [[ -z "${DBSNMP_PASSWORD}" ]]; then
            echo "DBSNMP password not found for ${ORACLE_SID}. Exiting."
            exit 1
        fi
        SYS_PASSWORD=$(get_password sys)
        if [[ -z "${SYS_PASSWORD}" ]]; then
            echo "SYS password not found for ${ORACLE_SID}. Exiting."
            exit 1
        fi

        for DB in $(echo -e "show configuration;" | dgmgrl / | grep "standby database" | cut -d'-' -f1)
        do
            report_differences ${ORACLE_SID} ${DB^^}
        done
    #else
        #echo "Skipping ${ORACLE_SID} as it is not the primary database."
    fi
done