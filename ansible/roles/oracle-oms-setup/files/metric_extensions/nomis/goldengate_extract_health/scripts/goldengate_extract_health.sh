#!/bin/bash
#
# Metric Extension: ME$GOLDENGATE_EXTRACT_HEALTH
#
# Reports one row per Oracle GoldenGate Extract.
#
# Status, lag and checkpoint age are taken from GGSCI "INFO ALL" so that the
# reported values match what a DBA sees in GGSCI.  These extracts mine redo
# shipped downstream, so the database capture views show the capture as caught
# up with the redo it has been given and understate the true lag.
#
# Errors and open transactions are read from DBA_CAPTURE and
# V$GOLDENGATE_TRANSACTION in the mining databases listed in /etc/oratab, and
# the trail location comes from the EXTTRAIL entry in the extract parameter file.
#
# Output (pipe delimited):
#   DATABASE|EXTRACT_NAME|STATUS|LAG_SECONDS|CHECKPOINT_AGE_SECONDS|
#   OLDEST_TRANSACTION_SECONDS|ERROR_COUNT|ERROR_NUMBER|ERROR_MESSAGE|TRAIL_FS_USED_PCT
#

. ~/.bash_profile

GG_HOME=${GG_HOME:-/u01/app/oracle/product/goldengate/19c}
GG_PARAM_DIR=${GG_PARAM_DIR:-${GG_HOME}/dirprm}
GG_ERROR_LOG=${GG_HOME}/ggserr.log

# Window (in minutes) over which OGG/ORA errors are counted in ggserr.log.
# Kept slightly wider than the collection interval so errors are not missed.
ERROR_WINDOW_MINUTES=${ERROR_WINDOW_MINUTES:-15}

# Function to retrieve passwords from AWS Secrets Manager
get_password() {
  USERNAME=$1
  PASSWORD=$(aws secretsmanager get-secret-value --secret-id "/oracle/database/$2/passwords" --region eu-west-2 --query SecretString --output text 2>/dev/null | jq -r .${USERNAME})
  echo "${PASSWORD}"
}

# Function to identify all ORACLE_SID values on the host
get_oracle_sids() {
  grep -E '^[^+#]' /etc/oratab | awk -F: 'NF && $1 ~ /^[^ ]/ {print $1}'
}

set_oracle_env() {
  export ORACLE_SID=$1
  export ORAENV_ASK=NO
  . oraenv >/dev/null 2>&1
}

hms_to_seconds() {
  echo "$1" | awk -F: '
    NF == 3 && $1 ~ /^[0-9]+$/ { print $1 * 3600 + $2 * 60 + $3; found = 1 }
    END { if (!found) print 0 }'
}

# Extract name, status, lag at checkpoint and time since checkpoint from GGSCI.
get_ggsci_info() {
  if [ ! -x "${GG_HOME}/ggsci" ]; then
    return
  fi
  # ggsci needs an Oracle environment, any local SID will do
  set_oracle_env "$(get_oracle_sids | head -1)"
  (cd "${GG_HOME}" && ./ggsci <<EOF 2>/dev/null
INFO ALL
EXIT
EOF
  ) | awk 'toupper($1) == "EXTRACT" && NF >= 3 {
             print $3 "|" toupper($2) "|" (NF >= 4 ? $4 : "") "|" (NF >= 5 ? $5 : "")
           }'
}

# Directory holding the trail files for an extract, from its parameter file.
get_trail_dir() {
  local EXTRACT_NAME=$1
  local PRM TRAIL
  for PRM in "${GG_PARAM_DIR}/${EXTRACT_NAME}.prm" \
             "${GG_PARAM_DIR}/$(echo "${EXTRACT_NAME}" | tr '[:upper:]' '[:lower:]').prm"; do
    if [ -r "${PRM}" ]; then
      TRAIL=$(awk 'toupper($1)=="EXTTRAIL" {print $2; exit}' "${PRM}")
      if [ -n "${TRAIL}" ]; then
        dirname "${TRAIL}"
        return
      fi
    fi
  done
  echo "${GG_HOME}/dirdat"
}

get_trail_fs_used_pct() {
  local TRAIL_DIR=$1
  if [ ! -d "${TRAIL_DIR}" ]; then
    echo 0
    return
  fi
  df -P "${TRAIL_DIR}" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print $5+0}'
}

# Count of OGG- and ORA- errors logged against an extract within the error window.
get_log_error_count() {
  local EXTRACT_NAME=$1
  if [ ! -r "${GG_ERROR_LOG}" ]; then
    echo 0
    return
  fi
  local CUTOFF
  CUTOFF=$(date -d "${ERROR_WINDOW_MINUTES} minutes ago" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
  if [ -z "${CUTOFF}" ]; then
    echo 0
    return
  fi
  # ggserr.log lines start with "YYYY-MM-DD HH:MM:SS" so string comparison is
  # equivalent to a chronological comparison.
  awk -v cutoff="${CUTOFF}" -v extract="${EXTRACT_NAME}" '
    /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]/ {
      line_time = substr($0, 1, 19)
      if (line_time >= cutoff && index($0, "ERROR") > 0 && index(toupper($0), toupper(extract)) > 0 &&
          (index($0, "OGG-") > 0 || index($0, "ORA-") > 0)) {
        count++
      }
    }
    END { print count+0 }
  ' "${GG_ERROR_LOG}"
}

run_sql() {
  local ORACLE_SID=$1
  set_oracle_env "$ORACLE_SID"
  if [ $? -ne 0 ]; then
    return
  fi

  # Exit without failure if database is not up
  srvctl status database -d $ORACLE_SID >/dev/null 2>&1
  if [ $? -ne 0 ]; then
    return
  fi

  sqlplus -s "$CONNECTION_STRING" <<EOF
SET PAGES 0
SET LINES 500
SET FEEDBACK OFF
SET ECHO OFF
SET HEAD OFF
SET TRIMSPOOL ON
SELECT UPPER(COALESCE(v.extract_name, d.client_name, d.capture_name)) || '|' ||
       SYS_CONTEXT('USERENV','DB_UNIQUE_NAME') || '|' ||
       TO_CHAR(NVL(d.error_number, 0)) || '|' ||
       NVL(SUBSTR(TRANSLATE(d.error_message, CHR(10) || CHR(13) || '|', '   '), 1, 200), 'NONE') || '|' ||
       TO_CHAR(ROUND(NVL((SELECT MAX((SYSDATE - t.first_message_time) * 86400)
                            FROM v\$goldengate_transaction t
                           WHERE t.component_type = 'CAPTURE'
                             AND t.component_name = d.capture_name), 0)))
  FROM dba_capture d
  LEFT JOIN v\$goldengate_capture v
    ON v.capture_name = d.capture_name
 WHERE UPPER(NVL(d.purpose, 'GOLDENGATE CAPTURE')) LIKE '%GOLDENGATE%';
EXIT
EOF
}

declare -A DB_INFO

for sid in $(get_oracle_sids); do

  DBSNMP_PASSWORD=$(get_password dbsnmp $sid)
  if [[ -n "$DBSNMP_PASSWORD" && "$DBSNMP_PASSWORD" != "null" ]]; then
    CONNECTION_STRING="dbsnmp/${DBSNMP_PASSWORD}"
  else
    CONNECTION_STRING="/ as sysdba"
  fi

  while IFS='|' read -r extract db error_number error_message oldest_txn; do
    extract=$(echo "$extract" | tr -d '[:space:]')
    [ -z "$extract" ] && continue
    DB_INFO["$extract"]="$(echo "$db" | tr -d '[:space:]')|${error_number// /}|${error_message}|${oldest_txn// /}"
  done < <(run_sql "$sid" | grep '|' | grep -v '^ORA-')

done

get_ggsci_info | while IFS='|' read -r extract gg_status lag_hms chkpt_hms; do
  [ -z "$extract" ] && continue

  db_row=${DB_INFO[$extract]}
  IFS='|' read -r db error_number error_message oldest_txn <<<"${db_row:-UNKNOWN|0|NONE|0}"

  lag_seconds=$(hms_to_seconds "$lag_hms")
  checkpoint_age=$(hms_to_seconds "$chkpt_hms")
  trail_fs_used_pct=$(get_trail_fs_used_pct "$(get_trail_dir "$extract")")

  error_count=$(get_log_error_count "$extract")
  if [ "${error_number}" -ne 0 ] 2>/dev/null; then
    error_count=$((error_count + 1))
  fi

  echo "${db}|${extract}|${gg_status}|${lag_seconds}|${checkpoint_age}|${oldest_txn}|${error_count}|${error_number}|${error_message}|${trail_fs_used_pct}"
done
