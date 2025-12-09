#!/bin/bash

. ~/.bash_profile

export ORACLE_SID=EMREP
export ORACLE_BASE=/u01/app/oracle
export ORAENV_ASK=NO
export PATH=$PATH:/usr/local/bin

. oraenv -s

function connect_to_emcli
{
   # Using -force within the same process can lead to session clashes, so we always just assume the session already exists
   # and only create a new session if it fails due to not being logged in (RC is 5).
   RM=$(${EMCLI} sync 2>&1)
   if [[ "$RM" == "Error: Session expired. Run emcli login to establish a session." ]];
   then
      SYSMAN_PWD=$(aws secretsmanager get-secret-value --secret-id /oracle/database/EMREP/shared-passwords --region ${REGION} --query SecretString --output text | jq -r .sysman)
      echo "${SYSMAN_PWD}" | ${EMCLI} login -username=sysman
      # Clear the password from memory immediately
      unset SYSMAN_PWD
   fi
}

MANAGEMENT_PACK_CHANGES=$(
sqlplus -s / as sysdba <<EOSQL
SET FEEDBACK OFF
SET LINES 2000
SET PAGES 0
SELECT
    target_name
    || '~'
    || target_type
    || '~'
    || application_name
    || '~'
    || existing_management_packs
    || '~'
    || requested_management_packs
    || '~'
    || existing_notifications_allowed
    || '~'
    || requested_notifications_allowed
FROM (
SELECT
    target_name,
    target_type,
    COALESCE(application_name,'UNKNOWN') application_name,
    COALESCE(existing_management_packs,'null') existing_management_packs,
    coalesce(
        LISTAGG(pack_name, '+') WITHIN GROUP(
        ORDER BY
            pack_name
        ),
        'none') requested_management_packs,
    COALESCE(existing_notifications_allowed,'null') existing_notifications_allowed,
    COALESCE(MAX(CASE WHEN pack_name = 'db_diag' THEN 'yes' ELSE null END),'no') requested_notifications_allowed
FROM
    (
        SELECT
            et1.target_name,
            et1.target_type,
            et1.host_name,
            mlv.pack_name,
            mtp1.property_value application_name,
            mtp2.property_value existing_management_packs,
            mtp3.property_value existing_notifications_allowed
        FROM
            sysman.em_targets             et1
            LEFT JOIN sysman.em_targets             et2 ON et1.host_name = et2.host_name
                                               AND et2.target_type = 'oracle_database'
            LEFT JOIN sysman.mgmt_license_view      mlv ON mlv.target_name = et2.target_name
                                                      AND mlv.target_type = 'oracle_database'
            LEFT JOIN sysman.mgmt\$target_properties mtp1 ON et1.target_guid = mtp1.target_guid
                                                            AND mtp1.property_name = 'orcl_gtp_line_of_bus'
            LEFT JOIN sysman.mgmt\$target_properties mtp2 ON et1.target_guid = mtp2.target_guid
                                                            AND mtp2.property_name = (
                SELECT
                    property_name
                FROM
                    sysman.mgmt\$all_target_prop_defs
                WHERE
                    property_display_name = 'Management Packs'
            )
            LEFT JOIN sysman.mgmt\$target_properties mtp3 ON et1.target_guid = mtp3.target_guid
                                                            AND mtp3.property_name = (
                SELECT
                    property_name
                FROM
                    sysman.mgmt\$all_target_prop_defs
                WHERE
                    property_display_name = 'Notifications Allowed'
            )
        WHERE
            et1.promote_status > 1 -- Ignore unpromoted targets
            AND et1.target_type NOT IN ( 'jrf_webservice', 'rest_webservice', 'oracle_si_filesystem_host',
                                         'oracle_si_network_interface_host' , 'oracle_si_network_data_link_host',
                                         'oracle_si_lvm_host', 'oracle_si_volume_host', 'asm_diskgroup_component',
                                         'composite', 'oracle_cloud', 'oracle_emd_proxy',
                                         'oracle_si_osservice_host' )
    )
GROUP BY
    target_name,
    target_type,
    application_name,
    existing_management_packs,
    existing_notifications_allowed
)
WHERE existing_management_packs != requested_management_packs
OR    existing_notifications_allowed != requested_notifications_allowed;
EXIT
EOSQL
)

if [[ ! -z ${MANAGEMENT_PACK_CHANGES} ]];
then

  REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region || echo "eu-west-2" | sed 's/[a-z]$//')
  CHANGE_LOG=/home/oracle/admin/em/management_pack_changes.$(date +%Y%m%d%H%M%S).log
  EMCLI=/u01/app/oracle/product/mw135/bin/emcli
  connect_to_emcli

  declare -A MANAGEMENT_PACKS_CHANGE_COUNT
  declare -A NOTIFICATIONS_ALLOWED_NO
  declare -A NOTIFICATIONS_ALLOWED_YES

  while IFS= read -r line;
  do
     TARGET_NAME=$(echo $line | cut -d~ -f1)
     TARGET_TYPE=$(echo $line | cut -d~ -f2)
     APPLICATION_NAME=$(echo $line | cut -d~ -f3)
     EXISTING_MANAGEMENT_PACKS=$(echo $line | cut -d~ -f4)
     REQUESTED_MANAGEMENT_PACKS=$(echo $line | cut -d~ -f5)
     EXISTING_NOTIFICATIONS_ALLOWED=$(echo $line | cut -d~ -f6)
     REQUESTED_NOTIFICATIONS_ALLOWED=$(echo $line | cut -d~ -f7)
     ${EMCLI} set_target_property_value -subseparator=property_records="~" \
	     -property_records="${TARGET_NAME}~${TARGET_TYPE}~Management Packs~${REQUESTED_MANAGEMENT_PACKS}"
     ${EMCLI} set_target_property_value -subseparator=property_records="~" \
	     -property_records="${TARGET_NAME}~${TARGET_TYPE}~Notifications Allowed~${REQUESTED_NOTIFICATIONS_ALLOWED}"
     if [[ $? == 0 ]];
     then
	     if [[ "${EXISTING_MANAGEMENT_PACKS}" != "${REQUESTED_MANAGEMENT_PACKS}" ]];
	     then
	        echo "$(date) Target ${TARGET_NAME}:${TARGET_TYPE} (${APPLICATION_NAME} application) management pack changed from ${EXISTING_MANAGEMENT_PACKS} to ${REQUESTED_MANAGEMENT_PACKS}." >> ${CHANGE_LOG}
	        if [[ -z "${MANAGEMENT_PACKS_CHANGE_COUNT[$APPLICATION_NAME]}" ]];
                then
		     MANAGEMENT_PACKS_CHANGE_COUNT[$APPLICATION_NAME]=0
	        fi
	        ((MANAGEMENT_PACKS_CHANGE_COUNT[$APPLICATION_NAME]++))
	     fi

	     if [[ "${EXISTING_NOTIFICATIONS_ALLOWED}" != "${REQUESTED_NOTIFICATIONS_ALLOWED}" ]];
	     then
		     if [[ "${REQUESTED_NOTIFICATIONS_ALLOWED}" == "yes" ]];
		     then
	                 echo "$(date) Target ${TARGET_NAME}:${TARGET_TYPE} (${APPLICATION_NAME} application) allowed notifications." >> ${CHANGE_LOG}
	                 if [[ -z "${NOTIFICATIONS_ALLOWED_YES[$APPLICATION_NAME]}" ]];
                         then
		            NOTIFICATIONS_ALLOWED_YES[$APPLICATION_NAME]=0
	                 fi
	                 ((NOTIFICATIONS_ALLOWED_YES[$APPLICATION_NAME]++))
	             else
	                 echo "$(date) Target ${TARGET_NAME}:${TARGET_TYPE} (${APPLICATION_NAME} application) disallowed notifications." >> ${CHANGE_LOG}
	                 if [[ -z "${NOTIFICATIONS_ALLOWED_NO[$APPLICATION_NAME]}" ]];
                         then
		            NOTIFICATIONS_ALLOWED_NO[$APPLICATION_NAME]=0
	                 fi
	                 ((NOTIFICATIONS_ALLOWED_NO[$APPLICATION_NAME]++))
		     fi
	     fi
     fi
  done <<< "${MANAGEMENT_PACK_CHANGES}"

  SLACK_TOKEN=$(aws secretsmanager get-secret-value --secret-id /oracle/database/EMREP/shared-passwords --region ${REGION} --query SecretString --output text | jq -r .slack_token)

  SLACK_CHANNEL="#hmpps-oem-alerts"
  EMOJI_ICON=":package:"
  USERNAME="Management Pack target property script"

  # Add keys from all arrays to determine which arrays have had changes made
  declare -A CHANGED_APPLICATIONS
  for key in "${!MANAGEMENT_PACKS_CHANGE_COUNT[@]}" "${!NOTIFICATIONS_ALLOWED_YES[@]}" "${!NOTIFICATIONS_ALLOWED_NO[@]}"; do
    CHANGED_APPLICATIONS["$key"]=1
  done

  for KEY in "${!CHANGED_APPLICATIONS[@]}";
  do
	  if [[ -z "${MANAGEMENT_PACKS_CHANGE_COUNT[$KEY]}" ]]
	  then
	     MANAGEMENT_PACKS_CHANGE_COUNT[$KEY]=0
	  fi
	  CHANGE_MESSAGE="${CHANGE_MESSAGE}\n:black_small_square: ${MANAGEMENT_PACKS_CHANGE_COUNT[$KEY]} management pack changes for *$KEY* targets"
	  if [[ ! -z "${NOTIFICATIONS_ALLOWED_YES[$KEY]}" ]]
	  then
		  CHANGE_MESSAGE="${CHANGE_MESSAGE}\n    - ${NOTIFICATIONS_ALLOWED_YES[$KEY]} target notifications were  allowed"
	  fi
	  if [[ ! -z "${NOTIFICATIONS_ALLOWED_NO[$KEY]}" ]]
	  then
		  CHANGE_MESSAGE="${CHANGE_MESSAGE}\n    - ${NOTIFICATIONS_ALLOWED_NO[$KEY]} target notifications were  disallowed"
	  fi
  done

  read -r -d '' BLOCKS <<EOM
[
  {
    "type": "header",
     "text": {
	"type": "plain_text",
        "text": "Updates applied to Oracle OEM Management Packs",
         }
     },
     {
        "type": "section",
        "text": {
           "type": "mrkdwn",
	   "text": "*Management Pack Updates:*\nThe following targets had their Management Pack property changed due to Management Pack Access updates to the $(hostname) OEM:${CHANGE_MESSAGE}"
          }
     },
     {
        "type": "section",
        "text": {
           "type": "mrkdwn",
	   "text": "Details of changes made have been logged on $(hostname) to the file ${CHANGE_LOG}"
          }
     }
]
EOM

  curl -X POST "https://slack.com/api/chat.postMessage" -H  "accept: application/json" -d token=${SLACK_TOKEN} -d channel=${SLACK_CHANNEL} -d text="Incident" -d blocks="$BLOCKS" -d icon_emoji="${EMOJI_ICON}" -d username="$USERNAME"
fi

exit 0