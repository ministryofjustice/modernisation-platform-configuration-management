#!/bin/bash

export ORACLE_SID=EMREP
export ORACLE_BASE=/u01/app/oracle
export ORAENV_ASK=NO
. oraenv -s

REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone || echo "eu-west-2" | sed 's/[a-z]$//')
EMCLI=/u01/app/oracle/product/mw135/bin/emcli
CHANGE_LOG=/tmp/management_pack_changes.$(date +%Y%m%d%H%M%S).log

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
FROM
(
SELECT
    target_name,
    target_type,
    COALESCE(application_name,'UNKNOWN') application_name,
    existing_management_packs,
    coalesce(
        LISTAGG(pack_name, '+') WITHIN GROUP(
        ORDER BY
            pack_name
        ),
        'none') requested_management_packs
FROM
    (
        SELECT
            et1.target_name,
            et1.target_type,
            et1.host_name,
            mlv.pack_name,
            mtp1.property_value application_name,
            mtp2.property_value existing_management_packs
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
        WHERE
            et1.target_type NOT IN ( 'jrf_webservice', 'rest_webservice', 'oracle_si_filesystem_host', 'oracle_si_network_interface_host'
            , 'oracle_si_network_data_link_host', 'oracle_si_lvm_host', 'oracle_si_volume_host', 'asm_diskgroup_component', 'composite', 'oracle_cloud'
            , 'oracle_dbsys', 'oracle_emd_proxy' )
    )
GROUP BY
    target_name,
    target_type,
    application_name,
    existing_management_packs
)
WHERE
    existing_management_packs != requested_management_packs;
EXIT
EOSQL
)

if [[ ! -z ${MANAGEMENT_PACK_CHANGES} ]];
then

  connect_to_emcli

  declare -A CHANGE_COUNT

  while IFS= read -r line;
  do
     ${EMCLI} set_target_property_value -subseparator=property_records="~" \
	     -property_records="$(echo $line | cut -d~ -f1)~$(echo $line | cut -d~ -f2)~Management Packs~$(echo $line | cut -d~ -f5)"
     if [[ $? == 0 ]];
     then
	     APPLICATION=$(echo $line | cut -d~ -f3)
	     if [[ -z "${CHANGE_COUNT[$APPLICATION]}" ]];
	     then
		     CHANGE_COUNT[$APPLICATION]=0
	     fi
	     ((CHANGE_COUNT[$APPLICATION]++))
	     echo "$(date) Target $(echo $line | cut -d~ -f1):$(echo $line | cut -d~ -f2) ($APPLICATION application) management pack changed from $(echo $line | cut -d~ -f4) to $(echo $line | cut -d~ -f5)." >> ${CHANGE_LOG}
     fi
  done <<< "${MANAGEMENT_PACK_CHANGES}"

  SLACK_TOKEN=$(aws secretsmanager get-secret-value --secret-id /oracle/database/EMREP/shared-passwords --region ${REGION} --query SecretString --output text | jq -r .slack_token)

  SLACK_CHANNEL="#delius-aws-oracle-dev-alerts-test"
  EMOJI_ICON=":package:"
  USERNAME="Management Pack target property script"

  for KEY in "${!CHANGE_COUNT[@]}";
  do
	  CHANGE_MESSAGE="${CHANGE_MESSAGE}\n:black_small_square: ${CHANGE_COUNT[$KEY]} management package changes for *$KEY* targets."
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
	   "text": "*Management Pack Updates:*\nThe following targets had their Management Pack property changed due to Management Pack Access updates in the $(hostname) OEM Console:${CHANGE_MESSAGE}"
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