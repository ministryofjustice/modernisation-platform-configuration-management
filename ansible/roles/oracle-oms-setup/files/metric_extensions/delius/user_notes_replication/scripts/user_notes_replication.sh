#!/bin/bash
#
# Count number of USER_ entries for the last day where:
# (1) The record was created by Data Maintenance
# (2) The NOTES field is NULL
# (3) It is not a SERVICE account
#
# If the count is non-zero this may have identified an audit stub user which has been replicated to this database
# with a missing Notes column.   (All such users should have Notes populated to state that they are stubs).

. ~/.bash_profile


if [[ $(srvctl config database -d ${ORACLE_SID} | awk -F: '/Start options/{print $2}' | tr -d ' ') == mount ]];
then
   # Ignore this metric on mounted (not open) databases
   exit 0
fi

sqlplus -s / as sysdba <<EOSQL
SET HEAD OFF
SET FEEDBACK OFF
SET PAGES 0


WITH data_maintenance_user AS (
    SELECT
        user_id
    FROM
        delius_app_schema.user_
    WHERE
        distinguished_name = '[Data Maintenance]'
)
SELECT
    COUNT(*) mssing_notes_count
FROM
    delius_app_schema.user_ u
WHERE
        u.created_datetime > sysdate - 1
    AND u.notes IS NULL
    AND u.created_by_user_id = (
        SELECT
            user_id
        FROM
            data_maintenance_user
    )
    AND u.user_id > (
        SELECT
            MAX(service_user.user_id)
        FROM
            delius_app_schema.user_ service_user
        WHERE
                service_user.surname = 'Service'
            AND service_user.created_by_user_id = (
                SELECT
                    user_id
                FROM
                    data_maintenance_user
            )
    );
EXIT
EOSQL