#!/bin/bash
#
# Metric Extension: ME$GOLDENGATE_REPLICAT_HEALTH
#
# Reports one row per Oracle GoldenGate Replicat.
#
# Status, lag and checkpoint age are taken from GGSCI "INFO ALL" so that the
# reported values match what a DBA sees in GGSCI.
#
# Apply errors are read from DBA_APPLY and DBA_APPLY_ERROR in the databases
# listed in /etc/oratab.  DBA_APPLY_ERROR holds a row per transaction the
# replicat could not apply, which is the usual symptom when a replicat abends
# after a table or column change on the source.
#
# Output (pipe delimited):
#   DATABASE|REPLICAT_NAME|STATUS|LAG_SECONDS|CHECKPOINT_AGE_MINUTES|
#   ERROR_COUNT|APPLY_ERROR_COUNT|ERROR_NUMBER|ERROR_MESSAGE
#

. ~/.bash_profile

GG_HOME=${GG_HOME:-/u01/app/oracle/product/goldengate/19c}
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

# Replicat name, status, lag at checkpoint and time since checkpoint from GGSCI.
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
  ) | awk 'toupper($1) == "REPLICAT" && NF >= 3 {
             print $3 "|" toupper($2) "|" (NF >= 4 ? $4 : "") "|" (NF >= 5 ? $5 : "")
           }'
}

# Count of OGG- and ORA- errors logged against a replicat within the error window.
get_log_error_count() {
  local REPLICAT_NAME=$1
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
  awk -v cutoff="${CUTOFF}" -v replicat="${REPLICAT_NAME}" '
    /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]/ {
      line_time = substr($0, 1, 19)
      if (line_time >= cutoff && index($0, "ERROR") > 0 && index(toupper($0), toupper(replicat)) > 0 &&
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
SELECT UPPER(a.apply_name) || '|' ||
       SYS_CONTEXT('USERENV','DB_UNIQUE_NAME') || '|' ||
       TO_CHAR(NVL(a.error_number, 0)) || '|' ||
       NVL(SUBSTR(TRANSLATE(a.error_message, CHR(10) || CHR(13) || '|', '   '), 1, 200), 'NONE') || '|' ||
       TO_CHAR((SELECT COUNT(*)
                  FROM dba_apply_error e
                 WHERE e.apply_name = a.apply_name))
  FROM dba_apply a
 WHERE UPPER(a.purpose) LIKE 'GOLDENGATE%';
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

  while IFS='|' read -r apply_name db error_number error_message apply_errors; do
    apply_name=$(echo "$apply_name" | tr -d '[:space:]')
    [ -z "$apply_name" ] && continue
    DB_INFO["$apply_name"]="$(echo "$db" | tr -d '[:space:]')|${error_number// /}|${error_message}|${apply_errors// /}"
  done < <(run_sql "$sid" | grep '|' | grep -v '^ORA-')

done

get_ggsci_info | while IFS='|' read -r replicat gg_status lag_hms chkpt_hms; do
  [ -z "$replicat" ] && continue

  # The inbound server for an integrated replicat is normally named after the
  # replicat, but can carry an OGG$ prefix.
  db_row=${DB_INFO[$replicat]:-${DB_INFO[OGG\$$replicat]}}
  IFS='|' read -r db error_number error_message apply_errors <<<"${db_row:-UNKNOWN|0|NONE|0}"

  lag_seconds=$(hms_to_seconds "$lag_hms")
  checkpoint_age_minutes=$(awk -v s="$(hms_to_seconds "$chkpt_hms")" 'BEGIN {printf "%.1f", s / 60}')

  error_count=$(get_log_error_count "$replicat")
  if [ "${error_number}" -ne 0 ] 2>/dev/null; then
    error_count=$((error_count + 1))
  fi

  echo "${db}|${replicat}|${gg_status}|${lag_seconds}|${checkpoint_age_minutes}|${error_count}|${apply_errors}|${error_number}|${error_message}"
done
