#!/bin/bash
BASEDIR=$(dirname "$0")
TEST_NUMBER=1
ON_EC2=0
NUM_OK=0
NUM_FAILED=0
DEBUG=${DEBUG:-0}

test_bip_control() {
  local flag

  flag=
  if ((DEBUG > 1)); then
    flag=-v
  fi

  printf "TEST %3d: %-80s - " "$TEST_NUMBER" "bip_control.sh $*"
  if output=$("$BASEDIR"/bip_control.sh $flag "$@" 2>&1); then
    echo "OK"
    if ((DEBUG > 0)); then
      echo "$output" >&2
    fi
    NUM_OK=$((NUM_OK + 1))
  else
    echo "FAILED"
    echo "$output" >&2
    NUM_FAILED=$((NUM_FAILED + 1))
  fi
  TEST_NUMBER=$((TEST_NUMBER + 1))
}

test_lb() {
  local ncr_env
  local lb_env

  ncr_env=$1
  lb_env=$2
  test_bip_control -d -e "$ncr_env" -l "$lb_env" lb maintenance-mode enable
  test_bip_control -d -e "$ncr_env" -l "$lb_env" lb maintenance-mode disable
  test_bip_control -e "$ncr_env" -l "$lb_env" lb maintenance-mode check
  test_bip_control -e "$ncr_env" -l "$lb_env" lb get-target-group arn
  test_bip_control -e "$ncr_env" -l "$lb_env" lb get-target-group health
  test_bip_control -e "$ncr_env" -l "$lb_env" lb get-target-group name
  test_bip_control -e "$ncr_env" -l "$lb_env" lb get-json         rules
  test_bip_control -e "$ncr_env" -l "$lb_env" lb get-json         rule
}

test_server_list() {
  local ncr_env
  local type

  ncr_env="$1"
  type="$2"
  test_bip_control -f fqdn -e "$ncr_env" "$type" server-list
  test_bip_control -e "$ncr_env" "$type" server-list
  test_bip_control -e "$ncr_env" "$type" server-list cms frs
  test_bip_control -e "$ncr_env" "$type" server-list all -cms -frs
  test_bip_control -e "$ncr_env" "$type" server-list event
  test_bip_control -e "$ncr_env" "$type" server-list job
  test_bip_control -e "$ncr_env" "$type" server-list processing
  test_bip_control -e "$ncr_env" "$type" server-list all -event -job -processing
}

test_diff() {
  local ncr_env

  ncr_env="$1"
  test_bip_control -f fqdn -e "$ncr_env" diff server-list "$2" "$3"
  test_bip_control -e         "$ncr_env" diff server-list "$2" "$3"
  test_bip_control -e         "$ncr_env" diff server-list "$2" "$3" cms frs
  test_bip_control -e         "$ncr_env" diff server-list "$2" "$3" all -cms -frs
}

test_ccm() {
  local ncr_env
  local server
  local sia

  ncr_env="$1"
  server="$2"
  sia="$3"
  if ((ON_EC2 == 1)); then
    test_bip_control -e "$ncr_env" ccm display
  else
    test_bip_control -d -e "$ncr_env" ccm display
  fi
  test_bip_control -d -e "$ncr_env" ccm disable "$server"
  test_bip_control -d -e "$ncr_env" ccm enable "$server"
  test_bip_control -d -e "$ncr_env" ccm managed-stop "$server"
  test_bip_control -d -e "$ncr_env" ccm managed-start "$server"
  test_bip_control -d -e "$ncr_env" ccm start "$sia"
  test_bip_control -d -e "$ncr_env" ccm stop "$sia"
}

test_environment() {
  if [[ -n $1 ]]; then
    export AWS_DEFAULT_PROFILE=$1
  fi
  ncr_env=$2
  if ((ON_EC2 == 1)); then
    test_server_list "$ncr_env" "ccm"
    test_diff "$ncr_env" ccm ec2
  fi
  test_server_list "$ncr_env" "biprws"
  test_server_list "$ncr_env" "ec2"
  test_ccm "$ncr_env" server.fqn sia.fqdn
  test_lb "$ncr_env" public
  test_lb "$ncr_env" private
  test_diff "$ncr_env" biprws ec2
}

token=$(curl -sS -m 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600" 2>/dev/null)
if [[ -n $token ]]; then
  instance_id=$(curl -sS -m 2 -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/instance-id)
  ncr_env_tag=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=nomis-combined-reporting-environment" --output text | cut -f5)
  ON_EC2=1
  test_environment "" "$ncr_env_tag"
else
  test_environment nomis-combined-reporting-test t1
  test_environment nomis-combined-reporting-preproduction pp
fi
echo "FINISHED: $NUM_OK OK; $NUM_FAILED FAILED"
