#!/bin/bash

. ~/.bash_profile

export PATH=$PATH:/usr/local/bin
ORACLE_SID=EMREP
ORAENV_ASK=NO
. oraenv
ORAENV_ASK=YES

# We only look for incidents in the period LOOKBACK_HOURS prior to the current time.  This defaults to 1 hour
# but may be overridden by setting this environment variable.
LOOKBACK_HOURS=${LOOKBACK_HOURS:=1}

REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')

CLEARED_INCIDENT_FILE=$(dirname $0)/cleared_incident_file
if [[ ! -f ${CLEARED_INCIDENT_FILE} ]];
then
   touch ${CLEARED_INCIDENT_FILE}
fi
MONITORING_SCHEDULE=$(dirname $0)/monitoring_schedule
EMCLI=/u01/app/oracle/product/mw135/bin/emcli

function connect_to_emcli
{
   # Using -force within the same process can lead to session clashes, so we always just assume the session already exists
   # and only create a new session if it fails due to not being logged in (RC is 5).
   RM=$(${EMCLI} sync 2>&1)
   if [[ "$RM" == "Error: Session expired. Run emcli login to establish a session." ]];
   then
      SYSMAN_PWD=$(aws secretsmanager get-secret-value --secret-id /oracle/database/EMREP/shared-passwords --region ${REGION} --query SecretString --output text | jq -r .sysman)
      ${EMCLI} login -username=sysman -password=${SYSMAN_PWD}
   fi
}


function delete_incident
{
INCIDENT_ID=$1
SUPPRESSED=$2
RESOLVED=$3
connect_to_emcli
if [[ "${SUPPRESSED}" == "Y" || "${RESOLVED}" == "Y" ]];
then
   # Suppressed or resolved incidents must be force deleted
   ${EMCLI} delete_incident_record -incident_number_list="${INCIDENT_ID}" -force
else
   ${EMCLI} delete_incident_record -incident_number_list="${INCIDENT_ID}"
fi
}

function suppress_incident
{
INCIDENT_ID=$1
connect_to_emcli
# We use a special dummy date (2 January 3456) which will not be in normal use
# to identify suppressions which were created by this script so that they can
# be unsuppressed later, once monitoring resumes
${EMCLI} suppress_incident -incident_id=${INCIDENT_ID} -suppress_type="UNTIL_SPECIFIED_DATE" -date="01023456"
${EMCLI} add_comment_to_incident -incident_id="${INCIDENT_ID}" -comment="Suppressed due to monitoring blackout."
}

function suppress_diagnostic_incident
{
INCIDENT_ID=$1
connect_to_emcli
# It is not possible to delete diagnostic incidents, so as an alternative we simply suppress them until
# they are cleared (or else forever).   Note that these incidents have a different comment attached to them
# compared to normal incidents, so will not be automatically unsuppressed at the start of a monitoring window.
${EMCLI} suppress_incident -incident_id=${INCIDENT_ID} -suppress_type="UNTIL_CLEARED"
${EMCLI} add_comment_to_incident -incident_id="${INCIDENT_ID}" -comment="Diagnostic incident suppressed."
}

function unsuppress_incident
{
INCIDENT_ID=$1
connect_to_emcli
${EMCLI} unsuppress_incident -incident_id=${INCIDENT_ID}
${EMCLI} add_comment_to_incident -incident_id="${INCIDENT_ID}" -comment="Unsuppressed due to end of monitoring blackout."
}

function log_slack_alert
{
INCIDENT_ID=$1
NEW_INCIDENT=$2
if [[ "${NEW_INCIDENT}" == "Y" ]];
then
   MESSAGE="Slack alert sent by script for creation of incident."
else
   MESSAGE="Slack alert sent by script for update of incident."
fi
connect_to_emcli
STDERR=$( ${EMCLI} add_comment_to_incident -incident_id="${INCIDENT_ID}" -comment="${MESSAGE}" 2>&1 )
[[ $STDERR =~ "Error: Unknown incident id" ]] && echo "UNKNOWN" || echo "OK"
}

function purge_cleared_incident_file
{
INCIDENT_LIST="$1"
# Remove incidents from the cleared incident file if they are no longer in scope
for INCIDENT_NUM in $(cat ${CLEARED_INCIDENT_FILE});
do
   if [[ "${INCIDENT_LIST}" =~ .*";${INCIDENT_NUM};".* ]];
   then
      :
   else
      echo "Incident ${INCIDENT_NUM} is cleared and no longer in scope."
      sed -i "/^${INCIDENT_NUM}$/d" ${CLEARED_INCIDENT_FILE}
   fi
done
}

# Generate List of Hostname & System Name Target Regular Expressions to Suppress
# (i.e. Those targets which are not within their monitoring schedule)
function create_suppression_list()
{
# Two Lists are used to prevent unwanted notifications:
#
#   SUPPRESSION_LIST is a list of regular expressions for targets
#   which are not within their monitoring schedule. For these targets
#   incidents of certain types are deleted (e.g. alert log errors),
#   whereas other incidents types (e.g. target down) are simply suppressed
#   until the dummy date of 02-Jan-3456.   They are then unsuppressed once
#   back within the monitoring schedule.   This is to allow notification
#   of stateful incidents when monitoring restarts if they have not been
#   cleared in the meantime.
#
#   NO_MONITORING_LIST is a list of regular expressions for targets
#   which are not being monitored at all (OFF in the monitoring_schedule
#   file).  All incidents for these targets are simply deleted.
#

# Use a dummy first expression in the Suppression List which will
# not match a valid host name (used to prevent a null pattern if
# every target is within their monitoring schedule)
SUPPRESSION_LIST='~'
NO_MONITORING_LIST='~'

while IFS= read LINE;
do
   COMMENTS='^#.*'
   if [[ ! "$LINE" =~ $COMMENTS ]];
   then
     TARGET=$(echo "$LINE" | awk '{print $1}')
     SCHEDULE_LINE=$(echo "$LINE" | tr '\t' ' ' | tr -s ' ' | cut -f 2- -d ' ')
     if [[ "${SCHEDULE_LINE}" =~ "OFF" ]];
     then
        echo "Not Monitoring $TARGET"
        NO_MONITORING_LIST="$NO_MONITORING_LIST|$TARGET"
     else
        export SCHEDULE_LINE
        SECONDS_TO_WITHIN_SCHEDULE_EXPR=$(ksh93 -c 'printf "(%(%s)T - %(%s)T)" "${SCHEDULE_LINE}" now')
        SECONDS_TO_WITHIN_SCHEDULE=$(echo "${SECONDS_TO_WITHIN_SCHEDULE_EXPR}" | bc )
        if [[ ${SECONDS_TO_WITHIN_SCHEDULE} -gt 180 ]];
        then
           echo "Suppressing $TARGET (Outside Monitoring Schedule $SCHEDULE_LINE)"
           SUPPRESSION_LIST="$SUPPRESSION_LIST|$TARGET"
        fi
     fi
   fi
done < ${MONITORING_SCHEDULE}
}

function suppress_excluded_hosts
{
#
#  Where hosts are not in a non-monitoring period (i.e. during normal hours)
#  they may also be suppressed from monitoring if a known period of maintenance is
#  in progress, such as password rotation.
#  Hosts which are under maintenance update the comment on the host target property in OEM
#  to log that they should be temporarily excluded from monitoring.
#  This can be acheived by appending these hosts to the existing SUPPRESSION_LIST so they are handled
#  in the same way as out-of-hours notifications (i.e. an alert can still be raised if an error
#  state still exists after the exclusion period expires).

# We get the list of excluded hosts from OEM for where Host Comment Property is Not null
connect_to_emcli
ALL_EXCLUDED_HOSTS=$(${EMCLI} get_targets -format="name:csv" | awk -F, '$3 == "host" {print $4}' | xargs -I {} ${EMCLI} list -resource="TargetProperties" -search="TARGET_NAME='{}'" -search="PROPERTY_NAME='orcl_gtp_comment'" -column="TARGET_NAME,PROPERTY_VALUE" -script -noheader | grep -E "\w+\s+Excluded from monitoring")

# If no currently excluded hosts then return without action
if [[ -z "${ALL_EXCLUDED_HOSTS}" || "${ALL_EXCLUDED_HOSTS}" == "NONE" ]];
then
   return
fi

CURRENT_TIMESTAMP=$(date +"%Y%m%d%H%M%S")

# We use an associative array and set the hostnames to be excluded as the keys.
# We do not set any values.
# This prevents the creation of duplicate entries as keys must be unique.
declare -A UNEXPIRED_EXCLUDED_HOSTS

while IFS= read LINE;
do
   EXCLUDED_HOST=$(echo $LINE | awk '{print $1}')
   EXCLUDE_EXPIRY=$(echo $LINE | awk '{print $NF}' | sed 's/-//g' )

   # If the exclusion expiry date is in the future, consider for inclusion
   if [[ ${EXCLUDE_EXPIRY} -gt ${CURRENT_TIMESTAMP} ]];
   then
      # If the host is not already a key to the array then add it
      # (avoiding duplicates)
      if [[ ! -v UNEXPIRED_EXCLUDED_HOSTS[${EXCLUDED_HOST}] ]];
      then
         UNEXPIRED_EXCLUDED_HOSTS[${EXCLUDED_HOST}]=
      fi
   elif [[ ${EXCLUDE_EXPIRY} -lt ${CURRENT_TIMESTAMP} ]];
   then
      # If the exclusion expiry date is in the past, this is probably due to whichever Ansible
      # job which set the exclusion having failed before it got round to removing
      # it.  Therefore we can tidy it up now and remove the expired exclusion comment.
      echo "Removing exclusion for $EXCLUDED_HOST"
      ${EMCLI} set_target_property_value -property_records="${EXCLUDED_HOST}:host:Comment:"
   else
      # If the exclusion expiry date is not set leave the exclusion in place.
      # If the host is not already a key to the array then add it
      # (avoiding duplicates)
      if [[ ! -v UNEXPIRED_EXCLUDED_HOSTS[${EXCLUDED_HOST}] ]];
      then
         UNEXPIRED_EXCLUDED_HOSTS[${EXCLUDED_HOST}]=
      fi
   fi
done <<< "${ALL_EXCLUDED_HOSTS}"

# Now append all excluded hosts to the existing suppression list
for TARGET in "${!UNEXPIRED_EXCLUDED_HOSTS[@]}"; do
    echo "Suppressing $TARGET (In Maintenance)"
    SUPPRESSION_LIST="$SUPPRESSION_LIST|$TARGET"
done
}

# Create list of targets to suppress due to out-of-hours (no monitoring)
create_suppression_list

# Extend suppression list to include hosts currently in maintenance (temporary exclusions)
suppress_excluded_hosts


# We check for any incidents in the last hour (using the annotations to
# ignore any which have already been dealt with).
# Note we must use the EM_INCIDENTS table as MGMT$INCIDENTS requires
# additional licencing.
INCIDENTS=$(
sqlplus -s /nolog <<EOSQL
SET HEADING OFF
SET FEEDBACK OFF
SET ECHO OFF
SET PAGES 0
SET LINES 2000
CONNECT / AS SYSDBA
WITH incidents
AS (
SELECT
    incident_num,
    latest_update,
    CASE WHEN contact IS NOT NULL THEN contact ELSE '#hmpps-oem-alerts' END ||'|'||
    incident_num||'|'||
    emoji_icon||'|'||
    CASE WHEN UPPER(target_name) LIKE '%_SYS* (%)'
    THEN TRIM(REPLACE(SUBSTR(target_name,1,INSTR(target_name,' ')),'*',''))
    ELSE SUBSTR(host_name,INSTR(host_name,':server:')+8)
    END||'|'||
    CASE WHEN REGEXP_INSTR(
          CASE WHEN UPPER(i.target_name) LIKE '%_SYS* (%)'
          THEN TRIM(REPLACE(SUBSTR(i.target_name,1,INSTR(i.target_name,' ')),'*',''))
               ||'=>'||    -- If target is a database system then consider it blacked-out if any of its constituent hosts are blacked-out
               (SELECT LISTAGG(DISTINCT mt.host_name,';') OVER (PARTITION BY incident_num)
                FROM  sysman.mgmt_target_memberships  mtm
                LEFT JOIN sysman.mgmt_targets mt
                ON mtm.member_target_name = mt.target_name
                WHERE TRIM(REPLACE(SUBSTR(i.target_name,1,INSTR(i.target_name,' ')),'*','')) = mtm.composite_target_name
                AND   mtm.composite_target_type = 'oracle_dbsys'
                FETCH FIRST ROW ONLY
                )
          ELSE SUBSTR(host_name,INSTR(host_name,':server:')+8)
          END,'${SUPPRESSION_LIST}') > 0 THEN 'Y' ELSE 'N'
    END||'|'||
    CASE WHEN REGEXP_INSTR(
          CASE WHEN UPPER(target_name) LIKE '%_SYS* (%)'
          THEN TRIM(REPLACE(SUBSTR(target_name,1,INSTR(target_name,' ')),'*',''))
          ELSE SUBSTR(host_name,INSTR(host_name,':server:')+8)
          END,'${NO_MONITORING_LIST}') > 0 THEN 'N' ELSE 'Y'
    END||'|'||
    CASE WHEN (SELECT MAX(eia1.annotation_date)
               FROM sysman.em_issues_annotations eia1
              WHERE eia1.issue_id=incident_id
                AND eia1.annotation_msg='Suppressed due to monitoring blackout.'
                AND NOT EXISTS (SELECT 1
                                  FROM sysman.em_issues_annotations eia2
                                 WHERE eia1.issue_id=eia2.issue_id
                                   AND eia2.annotation_date >= eia1.annotation_date
                                   AND eia2.annotation_msg = 'Unsuppressed due to end of monitoring blackout.')) IS NULL THEN 'N' ELSE 'Y'
    END||'|'||
    CASE WHEN resolution_state = 'resolved'
    THEN 'Y' ELSE 'N'
    END||'|'||
    CASE WHEN creation_date = last_updated_date
    THEN 'Y' ELSE 'N'
    END||'|'||
    CASE WHEN (SELECT MAX(eia.annotation_date)
               FROM   sysman.em_issues_annotations eia
               WHERE  incident_id = eia.issue_id
               AND    eia.annotation_msg LIKE 'Slack alert sent by script%') IS NULL THEN 'N'
    ELSE 'Y'
    END||'|'||
    blackout_deletable_incident||'|'||
    CASE WHEN is_adr_aware = 1
    THEN 'Y' ELSE 'N'
    END||'|'||
    username||'|'||
    JSON_ARRAY(JSON_OBJECT(
                   KEY 'type' VALUE 'divider'
               ), JSON_OBJECT(
           KEY 'type' VALUE 'section',
                  KEY 'fields' VALUE JSON_ARRAY(JSON_OBJECT(
                                             KEY 'type' VALUE 'mrkdwn',
                                             KEY 'text' VALUE created_time
                                         ),
              JSON_OBJECT(
               KEY 'type' VALUE 'mrkdwn',
              KEY 'text' VALUE target_name
           ),
              JSON_OBJECT(
               KEY 'type' VALUE 'mrkdwn',
              KEY 'text' VALUE local_time
           ),
              JSON_OBJECT(
               KEY 'type' VALUE 'mrkdwn',
              KEY 'text' VALUE host_name
           ))
       ),
               JSON_OBJECT(
        KEY 'type' VALUE 'section',
               KEY 'text' VALUE (JSON_OBJECT(
                                    KEY 'type' VALUE 'mrkdwn',
                                    KEY 'text' VALUE '\`\`\`' || REPLACE(summary_msg,'"','\"') || '\`\`\`'))
    )) message
FROM
    (
        SELECT
            ei.incident_id,
            ei.creation_date,
            ei.last_updated_date,
            GREATEST(ei.creation_date,ei.last_updated_date) latest_update,
            ei.incident_num,
            ei.suppressed_until,
            ei.resolution_state,
            ei.is_adr_aware,
            egtpe.lifecycle_status,
            egtpe.contact,
            CASE WHEN ei.severity > 0 AND non_deletable_events.incident_id IS NULL
            THEN 'Y' ELSE 'N' END blackout_deletable_incident,
            CASE ei.severity
                WHEN 0   THEN
                    ':green_circle:'
                WHEN 16  THEN
                    ':red_circle:'
                WHEN 32  THEN
                    ':black_circle:'
                ELSE
                    ':large_orange_circle:'
            END                                emoji_icon,
            CASE
                WHEN ei.severity=0
                AND  is_auto_close=1
                THEN
                    'Incident '
                    || ei.incident_num
                    || ' on '
                    || etg.display_name
                    || ' is auto closed'
                WHEN ei.severity=0 THEN
                    'Incident '
                    || ei.incident_num
                    || ' on '
                    || etg.display_name
                    || ' is cleared'
                WHEN ei.severity=16  THEN
                    'Critical Incident '
                    || ei.incident_num
                    || ' on '
                    || etg.display_name
                WHEN ei.severity=32  THEN
                    'Fatal Incident '
                    || ei.incident_num
                    || ' on '
                    || etg.display_name
                ELSE
                    'incident '
                    || ei.incident_num
                   || ' on '
                    || etg.display_name
            END                                username,
            ':clock1: '
            || to_char(ei.creation_date, 'DD-Mon-YYYY HH24:MI:SS')
            || ' UTC'                           created_time,
            '*'
            || etg.display_name
            || '* ('
            || etg.type_display_name
            || ')'                              target_name,
            '>'
            ||
            to_char(from_tz(CAST(ei.creation_date AS TIMESTAMP), 'UTC') AT TIME ZONE 'Europe/London', 'HH24:MI:SS')
            || ' '
            ||
            CASE
                WHEN ( from_tz(CAST(ei.creation_date AS TIMESTAMP), 'UTC') AT TIME ZONE 'Europe/London' ) = CAST(ei.creation_date
                AS TIMESTAMP) THEN
                        'GMT'
                ELSE
                    'BST'
            END
            local_time,
            ':server: ' || etg.host_name           host_name,
            ei.summary_msg       summary_msg
        FROM
            sysman.em_incidents    ei
            LEFT JOIN sysman.em_targets                    etg   ON ei.target_guid = etg.target_guid
            LEFT JOIN sysman.em_global_target_properties_e egtpe ON ei.target_guid = egtpe.target_guid
            LEFT JOIN sysman.em_problems                   ep    ON ei.related_problem_id = ep.problem_id
            LEFT JOIN (SELECT DISTINCT incident_id      -- We can delete the below listed event types
                        FROM   sysman.em_events         -- *if* they occur outside the monitoring schedule.
                        WHERE  event_name NOT IN        -- Not all event types may be deleted as some
                        (                               -- incidents should still be in place (e.g.
                        'Load:memUsedPct',              -- availability) at the end of monitoring.
                        'db_alert_log_status:genericErrors',
                        'alertLogAdrIncident:adr_problemKey',
                        'JobStatus',
                        'adrAlertLogOperationalError',
                        'UserAudit:username',
                        'adrAlertLogIncidentError:genericIncidentErrStack',
                        'adrAlertLogDataFailure:dataFailureErrStack',
                        'db_alert_log:genericErrStack',
                        'db_alert_log:blockCorruptErrStack',
                        'Performance:PerformanceValue',
                        'http_response:avg_response_time',
                        'Load:cpuUtil',
                        'adrAlertLogIncidentError',
                        'adrAlertLogIncidentError:accessViolationErrStack',
                        'db_alert_log_status',
                        'Security_Recommendations',
                        'clusterware_alerts:clusterwareErrStack',
                        'db_alert_log',
                        'TNS_ERRORS:tnserrmsg'
                        )
                        AND open_status > 0) non_deletable_events ON       ei.incident_id = non_deletable_events.incident_id
        WHERE ei.last_updated_date > CAST(SYSTIMESTAMP AT TIME ZONE 'UTC' - INTERVAL '${LOOKBACK_HOURS}' HOUR AS DATE)
        AND NOT ei.is_suppressed = 1
        AND NOT EXISTS (SELECT 1
                        FROM   sysman.em_issues_annotations eia
                        WHERE  ei.incident_id = eia.issue_id
                        AND    eia.annotation_msg LIKE 'Slack alert sent by script%'
                        AND    eia.annotation_date >= ei.last_updated_date)
        AND (ei.summary_msg NOT LIKE 'Incident (EM-03555 [EMOMS_PBS][core.pbs.gcloader.Util]) detected%'
             OR (ei.summary_msg LIKE 'Incident (EM-03555 [EMOMS_PBS][core.pbs.gcloader.Util]) detected%'
             AND NOT EXISTS (SELECT 1    -- Ignore Agent Out-of-Sync Diagnostics if the Agent was unblocked within half-an-hour of the error (due to delayed read of alert log)
                        FROM   sysman.em_incidents eau
                        WHERE  eau.summary_msg = 'Agent is unblocked'
                        AND    eau.creation_date BETWEEN ei.creation_date-(1/48) AND ei.creation_date+(1/48))))
        OR ei.suppressed_until = TO_DATE('02013456','DDMMYYYY')    -- Ignore suppressed except for those with the special date of 02013456 used to indicate temporary suppression
        ORDER BY
            incident_num
    ) i
)
SELECT message
FROM (
SELECT   0 incident_num,TO_CHAR(MAX(latest_update),'DD-Mon-YYYY HH24:MI:SS')||'|incident_num|hostname|in_blackout|monitoring|suppressed|resolved|new_incident|alert_sent|blackout_deletable_incident|diagnostic_incident|username|CHECK_DATE' message
FROM     sysman.incidents
UNION ALL
SELECT  incident_num,message
FROM   incidents
)
ORDER BY incident_num
;
EXIT
EOSQL
)

# Initialize list of all incident numbers still in scope
INCIDENT_LIST=";"
date

while read line; do
  if [[ "$line" =~ "|incident_num|hostname|in_blackout|monitoring|suppressed|resolved|new_incident|alert_sent|blackout_deletable_incident|username|CHECK_DATE" ]];
  then
     CHECK_DATE=$(echo $line | awk -F\| '{print $1}')
  else
     SLACK_CHANNEL=$(echo $line | awk -F\| '{print $1}')
     INCIDENT_NUM=$(echo $line | awk -F\| '{print $2}')
     INCIDENT_LIST="${INCIDENT_LIST}${INCIDENT_NUM};"
     echo "Incident List: ${INCIDENT_LIST}"
     EMOJI_ICON=$(echo $line | awk -F\| '{print $3}')
     HOSTNAME=$(echo $line | awk -F\| '{print $4}' )
     IN_BLACKOUT=$(echo $line | awk -F\| '{print $5}' )
     MONITORING=$(echo $line | awk -F\| '{print $6}' )
     SUPPRESSED=$(echo $line | awk -F\| '{print $7}' )
     RESOLVED=$(echo $line | awk -F\| '{print $8}' )
     NEW_INCIDENT=$(echo $line | awk -F\| '{print $9}' )
     ALERT_SENT=$(echo $line | awk -F\| '{print $10}' )
     BLACKOUT_DELETABLE_INCIDENT=$(echo $line | awk -F\| '{print $11}')
     DIAGNOSTIC_INCIDENT=$(echo $line | awk -F\| '{print $12}' )
     USERNAME=$(echo $line | awk -F\| '{print $13}')
     BLOCKS=$(echo $line | awk -F\| '{print $14}')
     echo "Check Date: ${CHECK_DATE} Line: $line"
     if [[ "${IN_BLACKOUT}" == "N" && "${MONITORING}" == "Y" ]];
     then
        . /etc/environment
        if [[ "${SUPPRESSED}" == "Y" ]];
        then
           # If incident has been suppressed from a previous blackout,
           # unsuppress it now but do not send a notification -
           # unsuppressing will trigger a change to the last updated
           # date so it will be notified in the subsequent run of this script
           if [[ "${EMOJI_ICON}" != ":green_circle:" ]];
           then
              echo "Unsuppressing incident ${INCIDENT_NUM}"
              unsuppress_incident ${INCIDENT_NUM}
           else
              # If the suppressed incident has been cleared in the
              # meantime we do not need to know about it so simply delete it
              echo "Deleting incident ${INCIDENT_NUM}"
              delete_incident ${INCIDENT_NUM} ${SUPPRESSED} ${RESOLVED}
           fi
        else
           if [[ "${EMOJI_ICON}" == ":green_circle:" && "${ALERT_SENT}" == "Y" ]];
           then
              # Occassionally incidents resolve themselves so quickly
              # that they have cleared before an alert has been sent
              # on slack.   (This most often occurs if an event occurs
              # when an EC2 instance is down and then the agent starts
              # marginally before other resources come online).
              # Therefore we do not send a clearance alert if a
              # preceding critical or warning alert was not sent as
              # this would just constitute noise.
              ALREADY_LOGGED=$(grep -c "^${INCIDENT_NUM}$" ${CLEARED_INCIDENT_FILE})
              # If this incident number is not already in the cleared incident file then send alert and add it
              if [[ $ALREADY_LOGGED -eq 0 ]];
              then
                echo "Alerting on Clearance of incident ${INCIDENT_NUM}"
		SLACK_TOKEN=$(aws secretsmanager get-secret-value --secret-id /oracle/database/EMREP/shared-passwords --region ${REGION} --query SecretString --output text | jq -r .slack_token)
                curl -X POST "https://slack.com/api/chat.postMessage" -H  "accept: application/json" -d token=${SLACK_TOKEN} -d channel=${SLACK_CHANNEL} -d text="Incident" -d blocks="$BLOCKS" -d icon_emoji="${EMOJI_ICON}" -d username="$USERNAME"
                 echo $INCIDENT_NUM >> ${CLEARED_INCIDENT_FILE}
              else
                # Otherwise do not send another alert
                echo "Clearance of incident ${INCIDENT_NUM} has already been alerted"
              fi
           elif [[ "${EMOJI_ICON}" != ":green_circle:" ]];
           then
              LOG_SLACK_ALERT=$( log_slack_alert ${INCIDENT_NUM} ${NEW_INCIDENT} )
              if [[ ${LOG_SLACK_ALERT} == "UNKNOWN" ]];
              then
                 echo "Incident could not be found - already closed (no alert required)"
              else
                 if [[ "${NEW_INCIDENT}" == "Y" ]];
                 then
                    echo "Alerting on New incident ${INCIDENT_NUM}"
                 else
                    echo "Alerting on Updated incident ${INCIDENT_NUM}"
                 fi
		 SLACK_TOKEN=$(aws secretsmanager get-secret-value --secret-id /oracle/database/EMREP/shared-passwords --region ${REGION} --query SecretString --output text | jq -r .slack_token)
                 curl -X POST "https://slack.com/api/chat.postMessage" -H  "accept: application/json" -d token=${SLACK_TOKEN} -d channel=${SLACK_CHANNEL} -d text="Incident" -d blocks="$BLOCKS" -d icon_emoji="${EMOJI_ICON}" -d username="$USERNAME"
              fi
           else
              echo "No alert required for cleared transient incident ${INCIDENT_NUM}"
           fi
        fi
     else
        # If monitoring is disabled (or in blackout), determine if we can
        # simply delete the incident or if it needs to be suppressed until monitoring is enabled again.
        if [[ "$BLACKOUT_DELETABLE_INCIDENT" == "Y" || "${MONITORING}" == "N" || "${EMOJI_ICON}" == ":green_circle:" ]];
        then
           if [[ "$DIAGNOSTIC_INCIDENT" == "Y" ]];
           then
              echo "Suppressing diagnostic incident ${INCIDENT_NUM}"
              suppress_diagnostic_incident ${INCIDENT_NUM}
           else
              echo "Deleting incident ${INCIDENT_NUM}"
              delete_incident ${INCIDENT_NUM} ${SUPPRESSED} ${RESOLVED}
           fi
        else
           if [[ "$SUPPRESSED" == "N" ]];
           then
              echo "Suppressing incident ${INCIDENT_NUM}"
              suppress_incident ${INCIDENT_NUM}
           fi
        fi
     fi
   fi
done < <(echo "${INCIDENTS}")

# Get rid of incidents in the cleared incident file which are no longer within scope
purge_cleared_incident_file "${INCIDENT_LIST}"
echo