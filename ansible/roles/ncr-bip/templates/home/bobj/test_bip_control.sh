#!/bin/bash
BASEDIR=$(dirname "$0")
TEST_NUMBER=1
NUM_OK=0
NUM_FAILED=0
DEBUG=0

test_bip_control() {
  printf "TEST %3d: %-80s - " "$TEST_NUMBER" "bip_control.sh $*"
  if output=$("$BASEDIR"/bip_control.sh "$@" 2>&1); then
    echo "OK"
    if [[ $DEBUG -eq 1 ]]; then
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
  test_bip_control -dv -e "$ncr_env" lb-enable-maintenance-mode "$lb_env"
  test_bip_control -dv -e "$ncr_env" lb-disable-maintenance-mode "$lb_env"
  test_bip_control -dv -e "$ncr_env" lb-get-maintenance-mode "$lb_env"
  test_bip_control -dv -e "$ncr_env" lb-get-target-group-arn "$lb_env"
  test_bip_control -dv -e "$ncr_env" lb-get-target-group-health "$lb_env"
  test_bip_control -dv -e "$ncr_env" lb-get-target-group-name "$lb_env"
  test_bip_control -dv -e "$ncr_env" lb-get-listener-rules-json "$lb_env"
  test_bip_control -dv -e "$ncr_env" lb-get-rule-json "$lb_env"
}

test_biprws() {
  local ncr_env

  ncr_env="$1"
  test_bip_control -dv -e "$ncr_env" biprws-get-servers
  test_bip_control -dv -q -e "$ncr_env" biprws-get-servers
  test_bip_control -dv -e "$ncr_env" biprws-get-servers-except-cms-frs
  test_bip_control -dv -e "$ncr_env" biprws-get-event-servers
  test_bip_control -dv -e "$ncr_env" biprws-get-job-servers
  test_bip_control -dv -e "$ncr_env" biprws-get-processing-servers
  test_bip_control -dv -e "$ncr_env" biprws-get-other-servers
}

test_ccm() {
  local ncr_env
  local server
  local sia

  ncr_env="$1"
  server="$2"
  sia="$3"
  test_bip_control -dv -e "$ncr_env" ccm-display
  test_bip_control -dv -e "$ncr_env" ccm-disable "$server"
  test_bip_control -dv -e "$ncr_env" ccm-enable "$server"
  test_bip_control -dv -e "$ncr_env" ccm-managed-stop "$server"
  test_bip_control -dv -e "$ncr_env" ccm-managed-start "$server"
  test_bip_control -dv -e "$ncr_env" ccm-start "$sia"
  test_bip_control -dv -e "$ncr_env" ccm-stop "$sia"
}

test_environment() {
  if [[ -n $1 ]]; then
    export AWS_DEFAULT_PROFILE=$1
  fi
  ncr_env=$2
  test_biprws "$ncr_env"
  test_ccm "$ncr_env" server.fqn sia.fqdn
  test_lb "$ncr_env" public
  test_lb "$ncr_env" private
}

token=$(curl -sS -m 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600" 2>/dev/null)
if [[ -n $token ]]; then
  instance_id=$(curl -sS -m 2 -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/instance-id)
  ncr_env_tag=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=nomis-combined-reporting-environment" --output text | cut -f5)
  test_environment "" "$ncr_env_tag"
else
  test_environment nomis-combined-reporting-test t1
  test_environment nomis-combined-reporting-preproduction pp
fi
echo "FINISHED: $NUM_OK OK; $NUM_FAILED FAILED"
