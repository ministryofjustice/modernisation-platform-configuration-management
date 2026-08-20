#!/bin/bash
. ~/.bash_profile

set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "Usage: $0 <directory_name> <directory_path> <report_filename> <replay_name> <tns_alias>" >&2
  exit 1
fi

report_directory_name="$1"
report_directory_path="$2"
report_filename="$3"
replay_name="$4"
tns_alias="$5"
target_db_name="${TARGET_DB_NAME:-${ORACLE_SID:-}}"
rat_secret_id="${RAT_SECRET_ID:-}"
aws_region="${AWS_REGION:-}"

if [[ -z "${target_db_name}" ]]; then
  echo "Set TARGET_DB_NAME or ORACLE_SID before running this script." >&2
  exit 1
fi

if [[ -z "${tns_alias}" ]]; then
  echo "Set tns_alias before running this script." >&2
  exit 1
fi

if [[ -z "${rat_secret_id}" || -z "${aws_region}" ]]; then
  echo "Set RAT_SECRET_ID and AWS_REGION before running this script." >&2
  exit 1
fi

echo "Report directory name: ${report_directory_name}"
echo "Report directory path: ${report_directory_path}"
echo "Report filename: ${report_filename}"
echo "Replay name: ${replay_name}"
echo "Target database name: ${target_db_name}"

export PATH="$PATH:/usr/local/bin"
rat_replay_password="$(aws secretsmanager get-secret-value \
  --secret-id "${rat_secret_id}" \
  --region "${aws_region}" \
  --query SecretString \
  --output text | jq -er '.rat_replay')"

if [[ -z "${rat_replay_password}" ]]; then
  echo "RAT_REPLAY password is empty in secret ${rat_secret_id}." >&2
  exit 1
fi

export ORAENV_ASK=NO
export ORACLE_SID="${target_db_name}"
. oraenv -s

sqlplus -s /nolog <<EOF
whenever sqlerror exit failure
connect RAT_REPLAY/${rat_replay_password}@${tns_alias}
set serveroutput on
declare
begin
  begin
    execute immediate 'create directory $report_directory_name as ''$report_directory_path''';
  exception
    when others then
      if sqlcode != -955 then
        raise;
      end if;
  end;
end;
/

declare
  l_file       utl_file.file_type;
  l_clob       clob;
  l_buffer     varchar2(32767);
  l_amount     binary_integer := 32767;
  l_pos        integer := 1;
  l_replay_id  number;
begin
  begin
    select id into l_replay_id
      from (select id from dba_workload_replays where name = '$replay_name' and status = 'COMPLETED' order by id desc)
     where rownum = 1;
  exception
    when no_data_found then
      raise_application_error(-20001, 'No COMPLETED replay found in dba_workload_replays with name ''$replay_name''');
  end;

  l_clob := DBMS_WORKLOAD_REPLAY.REPORT(
              replay_id => l_replay_id,
              format    => 'HTML');

  l_file := UTL_FILE.FOPEN(
                location     => '$report_directory_name',
                filename     => '$report_filename',
                open_mode    => 'W',
                max_linesize => 32767
            );

  loop
    dbms_lob.read(l_clob, l_amount, l_pos, l_buffer);
    utl_file.put(l_file, l_buffer);
    utl_file.fflush(l_file);
    l_pos := l_pos + l_amount;
  end loop;
exception
  when no_data_found then
    -- Expected end of CLOB read.
    if utl_file.is_open(l_file) then
      utl_file.fclose(l_file);
    end if;
  when others then
    if utl_file.is_open(l_file) then
      utl_file.fclose(l_file);
    end if;
    raise;
end;
/
exit
EOF
