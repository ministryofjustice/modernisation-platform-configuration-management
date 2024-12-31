#!/bin/bash
# Helper script for BIP to
# - run ccm.sh grabbing password from secret
# - enable/disable admin mode on load balancer
# - retrieve server list from API
# - start/stop environment cleanly
#
#SEE: https://me.sap.com/notes/0002390652
#1. Stop the Web Application Server (Tomcat or other).
#2. Disable all services except the Central Management Server, Input File Repository Server and Output File Repository Server.
#3. Wait for 10 minutes.
#4. Stop the Event Servers.
#5. Stop all Job Servers.
#6. Stop all Processing servers (Example: Crystal Processing Servers / Web Intelligence Processing Servers)
#7. Stop the rest of the servers.
#8. Stop SIA.
#To restart, Follow the above steps, in the reverse order (9 to 1).
#
# 2. ./ncr_control.sh -l pp | grep -Ev 'CentralManagementServer|InputFileRepository|OutputFileRepository|Disabled'

DRYRUN=0
VERBOSE=0
LB=private
PRINT_FQDN_ONLY=0
CCM_SH="{{ sap_bip_installation_directory }}/sap_bobj/ccm.sh"

usage() {
  echo "Usage $0: <opts> <cmd>

Where <opts>:
  -d                     Enable dryrun for maintenance mode commands
  -e <env>               Optionally set nomis-combined-reporting environment, otherwise derive from EC2 tag
  -l public|private      Select LB to act on, default is $LB
  -q                     Just display FQDNs for BIP output
  -v                     Enable verbose debug

Where <cmd>:
  biprws     server-list                [<servers>]          - use BIPRWS API to print BIP given servers
  ccm        display                                         - use ccm.sh to display servers
  ccm        disable|enable             <servers>            - use ccm.sh to enable/disable server(s)
  ccm        managed-start|managed-stop <servers>            - use ccm.sh to start/stop server(s)
  ccm        start|stop                 <sianames>           - use ccm.sh to start/stop sia(s)
  lb         maintenance-mode           enable|disable|check - enable, disable or check maintenance mode on given LB
  lb         get-target-group           arn|health|name      - get target group ARN, health or name on given LB
  lb         get-json                   rules|rule           - debug lb json

Where <servers> are space separated and can be:
  <fqdn>     - fqdn of server name, e.g. ppncrcms1.AdaptiveJobServer
  all        - all servers
  cms        - all CentralManagementServer servers
  frs        - all InputFileRepository and OutputFileRepository servers
  event      - all EventServer servers
  processing - all ProcessingServer servers, e.g. WebIntelligenceProcessingServer
  +<server>  - prefix with a plus to combine with previous filter
  -<server>  - prefix with a minus to subtract from previous filter
e.g.
  $0 biprws server-list all -cms -frs        # to display all servers except CMS and FRS
  $0 biprws server-list processing +Stopped  # to display all stopped processing servers

" >&2
  return 1
}

debug() {
  if ((VERBOSE != 0)); then
    echo "DEBUG: $*" >&2
  fi
}

dryrun_debug() {
  if ((DRYRUN != 0)); then
    echo "DRYRUN: $*" >&2
  elif ((VERBOSE != 0)); then
    echo "DEBUG: $*" >&2
  fi
}

error() {
  echo "$@" >&2
}

set_env_variables() {
  PUBLIC_LB_NAME=public-lb
  PUBLIC_LB_RULE_MAINTENANCE_PRIORITY=999
  PUBLIC_LB_PORT=443
  PUBLIC_LB_BACKEND_PORT=7777
  PRIVATE_LB_NAME=private-lb
  PRIVATE_LB_RULE_MAINTENANCE_PRIORITY=999
  PRIVATE_LB_PORT=7777
  PRIVATE_LB_BACKEND_PORT=7777

  if [[ $NCR_ENVIRONMENT == t1 ]]; then
    ADMIN_URL=t1.test.reporting.nomis.service.justice.gov.uk
    PUBLIC_LB_URL=t1.test.reporting.nomis.service.justice.gov.uk
    PRIVATE_LB_URL=t1-int.test.reporting.nomis.service.justice.gov.uk
  elif [[ $NCR_ENVIRONMENT == ls ]]; then
    ADMIN_URL=ls.preproduction.reporting.nomis.service.justice.gov.uk
    PUBLIC_LB_URL=ls.preproduction.reporting.nomis.service.justice.gov.uk
    PRIVATE_LB_URL=ls-int.preproduction.reporting.nomis.service.justice.gov.uk
  elif [[ $NCR_ENVIRONMENT == pp ]]; then
    ADMIN_URL=admin.preproduction.reporting.nomis.service.justice.gov.uk
    PUBLIC_LB_URL=preproduction.reporting.nomis.service.justice.gov.uk
    PRIVATE_LB_URL=int.preproduction.reporting.nomis.service.justice.gov.uk
  elif [[ $NCR_ENVIRONMENT == pd ]]; then
    ADMIN_URL=admin.reporting.nomis.service.justice.gov.uk
    PUBLIC_LB_URL=reporting.nomis.service.justice.gov.uk
    PRIVATE_LB_URL=int.reporting.nomis.service.justice.gov.uk
  else
    error "Unsupported nomis-combined-reporting-environment value '$NCR_ENVIRONMENT'"
    return 1
  fi
}

set_env_instance_id() {
  debug "curl -sS -X PUT http://169.254.169.254/latest/api/token"
  token=$(curl -sS -m 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600")
  INSTANCE_ID=$(curl -sS -m 2 -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/instance-id)
}

set_env_ncr_environment() {
  debug "aws ec2 describe-tags"
  NCR_ENVIRONMENT=$(aws ec2 describe-tags --no-cli-pager --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=nomis-combined-reporting-environment" --output text | cut -f5)
  if [[ -z $NCR_ENVIRONMENT ]]; then
    error "Unable to retrieve nomis-combined-reporting-environment tag"
    return 1
  fi
}

set_env_ncr_ec2s() {
  debug "aws ec2 describe-instances"
}

set_env_lb() {
  if [[ $1 == "public" ]]; then
    LB_NAME=$PUBLIC_LB_NAME
    LB_RULE_MAINTENANCE_PRIORITY=$PUBLIC_LB_RULE_MAINTENANCE_PRIORITY
    LB_PORT=$PUBLIC_LB_PORT
    LB_BACKEND_PORT=$PUBLIC_LB_BACKEND_PORT
    LB_URL=$PUBLIC_LB_URL
  elif [[ $1 == "private" ]]; then
    LB_NAME=$PRIVATE_LB_NAME
    LB_RULE_MAINTENANCE_PRIORITY=$PRIVATE_LB_RULE_MAINTENANCE_PRIORITY
    LB_PORT=$PRIVATE_LB_PORT
    LB_BACKEND_PORT=$PRIVATE_LB_BACKEND_PORT
    LB_URL=$PRIVATE_LB_URL
  else
    error "Unexpected loadbalancer '$1', expected public or private"
    return 1
  fi
}

set_env_admin_password() {
  debug "aws secretsmanager get-secret-value --secret-id /sap/bip/$NCR_ENVIRONMENT/passwords --query SecretString --output text"
  ADMIN_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "/sap/bip/$NCR_ENVIRONMENT/passwords" --query SecretString --output text | jq -r ".Administrator")
  if [[ -z $ADMIN_PASSWORD || $ADMIN_PASSWORD == 'null' ]]; then
    error "Unable to retrieve Administrator password from '/sap/bip/$NCR_ENVIRONMENT/passwords' secret"
    return 1
  fi
}

set_env_biprws_logon_token() {
  local logon
  local token_json
  local logon_token
  local error_code
  local message

  debug "curl https://$ADMIN_URL/biprws/v1/logon/long"
  logon='{"username": "Administrator", "password": "'"$ADMIN_PASSWORD"'", "auth": "secEnterprise"}'
  token_json=$(curl -Ss -m 5 -H "Content-Type: application/json" -H "Accept: application/json" --data "$logon" "https://$ADMIN_URL/biprws/v1/logon/long")
  error_code=$(jq -r .error_code <<< "$token_json")
  message=$(jq -r .message <<< "$token_json")
  if [[ $error_code != 'null' ]]; then
    error "Logon API returned error: $error_code: $message"
    return 1
  fi
  logon_token=$(jq -r ".logontoken" <<< "$token_json")
  if [[ -z $logon_token || $logon_token == 'null' ]]; then
    error "Logon API didn't return token: $token_json"
    return 1
  fi
  BIPRWS_LOGON_TOKEN="\"$logon_token\""
}

biprws_get() {
  local uri

  uri="$1"
  debug "curl $uri"
  curl -Ss -m 5 -H "Content-Type: application/json" -H "Accept: application/json" -H "X-SAP-LogonToken: $BIPRWS_LOGON_TOKEN" "$uri"
}

biprws_get_pages() {
  local uri
  local page
  local json
  local nexturi
  local lasturi

  uri="$1"
  page=1

  while true; do
    if ! json=$(biprws_get "$uri"); then
      return 1
    fi
    error_code=$(jq -r .error_code <<< "$json")
    message=$(jq -r .message <<< "$json")
    if [[ $error_code != 'null' ]]; then
      error "API returned error: $error_code: $message"
      return 1
    fi
    nexturi=$(jq -r .next.__deferred.uri <<< "$json" | sed "s/http:/https:/g")
    lasturi=$(jq -r .last.__deferred.uri <<< "$json" | sed "s/http:/https:/g")
    jq '.entries[]' <<< "$json"
    if [[ "$uri" == "$lasturi" || "$nexturi" == "null" ]]; then
      break
    fi
    if [[ "$uri" == "$nexturi" ]]; then
      error "API paging error: unexpected nexturi: $nexturi"
      return 1
    fi
    if (( page == 1000 )); then
      error "API paging error: reached page 1000"
      return 1
    fi
    uri="$nexturi"
    page=$((page + 1))
  done
}

grep_server_list() {
  local filter
  local list
  local flags
  local opt

  list="$1"
  opt="$2"
  filter="$3"

  if [[ -z $list ]]; then
    return
  fi

  flags=
  if [[ $opt == "subtract" ]]; then
    flags="-v"
  elif [[ $opt != "add" ]]; then
    if [[ -n $opt ]]; then
      echo "$opt"
    fi
  fi

  if [[ $filter == "all" ]]; then
    if [[ $opt != "subtract" ]]; then
      echo "$list"
    fi
  elif [[ $filter == "cms" ]]; then
    grep $flags CentralManagementServer <<< "$list"
  elif [[ $filter == "frs" ]]; then
    grep $flags FileRepository <<< "$list"
  elif [[ $filter == "event" ]]; then
    grep $flags EventServer <<< "$list"
  elif [[ $filter == "job" ]]; then
    grep $flags JobServer <<< "$list"
  elif [[ $filter == "processing" ]]; then
    grep $flags ProcessingServer <<< "$list"
  else
    grep $flags "$filter" <<< "$list"
  fi
}

filter_server_list() {
  local filter
  local list
  local output

  list="$1"
  output=""
  shift
  if (( $# == 0 )); then
    sort -uf <<< "$list"
  else
    for filter; do
      if [[ $filter = +* ]]; then
        output=$(grep_server_list "$output" "add" "${filter:1}")
      elif [[ $filter = -* ]]; then
        output=$(grep_server_list "$output" "subtract" "${filter:1}")
      else
        output=$(grep_server_list "$list" "$output" "$filter")
      fi
    done
    sort -uf <<< "$output"
  fi
}

ccm() {
  dryrun_debug "ccm.sh $* -username Administrator -password xxx"
  if (( DRYRUN == 0 )); then
    if [[ ! -x "$CCM_SH" ]]; then
      error "Error ccm.sh script not found: $CCM_SH"
      return 1
    fi
    "$CCM_SH" "$@" -username Administrator -password "$ADMIN_PASSWORD"
  fi
}

lb_get_listener_rules_json() {
  local lbarn
  local listenerarn

  debug "aws elbv2 describe-load-balancers"
  lbarn=$(aws elbv2 describe-load-balancers --no-cli-pager | jq -r '.LoadBalancers[] | select(.LoadBalancerName=="'"$LB_NAME"'").LoadBalancerArn')
  if [[ -z $lbarn ]]; then
    error "Error retriving load balancer details for $LB_NAME"
    return 1
  fi
  debug "aws elbv2 describe-listeners --load-balancer-arn '$lbarn'"
  listenerarn=$(aws elbv2 describe-listeners --load-balancer-arn "$lbarn" --no-cli-pager | jq -r '.Listeners[] | select(.Port=='"$LB_PORT"').ListenerArn')
  if [[ -z $listenerarn ]]; then
    error "Error retrieving load balancer port $LB_PORT listener for $LB_NAME"
    return 1
  fi
  debug "aws elbv2 describe-rules --listener-arn '$listenerarn'"
  aws elbv2 describe-rules --listener-arn "$listenerarn" --no-cli-pager
}

lb_get_rule_json() {
  local rules_json
  local rules_json1
  local rules_json2
  local rules_json3
  local num_rules

  if ! rules_json1=$(lb_get_listener_rules_json); then
    return 1
  fi
  if ! rules_json2=$(jq '.Rules[] | select(.Actions | length != 0)' <<< "$rules_json1"); then
    debug "$rules_json1"
    error "Error finding rules with actions"
    return 1
  fi
  if ! rules_json3=$(jq -s '.[] | select(.Priority != "'"$LB_RULE_MAINTENANCE_PRIORITY"'")' <<< "$rules_json2"); then
    debug "$rules_json2"
    error "Error finding rules excluding maintenance mode"
    return 1
  fi
  if ! rules_json=$(jq -s '.[] | select([.Conditions[].Values[] == "'"$LB_URL"'"] | any)' <<< "$rules_json3"); then
    debug "$rules_json3"
    error "Error finding rules with conditions matching $LB_URL"
    return 1
  fi
  num_rules=$(jq -s '. | length' <<< "$rules_json")
  if [[ -z $num_rules ]]; then
    debug "$rules_json"
    error "Error counting lb rules for $LB_URL"
    return 1
  fi
  if [[ $num_rules -eq 0 ]]; then
    debug "$rules_json3"
    error "Error finding matching lb rule for $LB_URL"
    return 1
  fi
  if [[ $num_rules -ne 1 ]]; then
    debug "$rules_json"
    error "Error finding unique lb rule for $LB_URL"
    return 1
  fi
  echo "$rules_json"
}

lb_disable_maintenance_mode() {
  local lbrulejson
  local priority
  local num_priorities
  local rulearn
  local json

  if ! lbrulejson=$(lb_get_rule_json); then
    return 1
  fi
  rulearn=$(jq -r '.RuleArn' <<< "$lbrulejson")
  priority=$(jq -r '.Priority' <<< "$lbrulejson")
  num_priorities=$(wc -l <<< "$priority" | tr -d " ")
  if [[ -z $priority || $num_priorities != "1" ]]; then
    debug "$lbrulejson"
    error "Error detecting weblogic lb rule priority $num_priorities"
    return 1
  fi
  if ((priority > LB_RULE_MAINTENANCE_PRIORITY)); then
    newpriority=$((priority - 1000))
    dryrun_debug "aws elbv2 set-rule-priorities --rule-priorities 'RuleArn=$rulearn,Priority=$newpriority' --no-cli-pager"
    if (( DRYRUN == 0 )); then
      json=$(aws elbv2 set-rule-priorities --rule-priorities "RuleArn=$rulearn,Priority=$newpriority" --no-cli-pager)
      debug "$json"
      echo "maintenance mode disabled"
    fi
  else
    echo "maintenance mode already disabled"
  fi
}

lb_enable_maintenance_mode() {
  local lbrulejson
  local priority
  local num_priorities
  local rulearn
  local json

  if ! lbrulejson=$(lb_get_rule_json); then
    return 1
  fi
  rulearn=$(jq -r '.RuleArn' <<< "$lbrulejson")
  priority=$(jq -r '.Priority' <<< "$lbrulejson")
  num_priorities=$(wc -l <<< "$priority" | tr -d " ")
  if [[ -z $priority || $num_priorities != "1" ]]; then
    debug "$lbrulejson"
    error "Error detecting weblogic lb rule priority"
    return 1
  fi
  if ((priority < LB_RULE_MAINTENANCE_PRIORITY)); then
    newpriority=$((priority + 1000))
    dryrun_debug "aws elbv2 set-rule-priorities --rule-priorities 'RuleArn=$rulearn,Priority=$newpriority' --no-cli-pager"
    if (( DRYRUN == 0 )); then
      json=$(aws elbv2 set-rule-priorities --rule-priorities "RuleArn=$rulearn,Priority=$newpriority" --no-cli-pager)
      debug "$json"
      echo "maintenance mode enabled"
    fi
  else
    echo "maintenance mode already enabled"
  fi
}

lb_get_maintenance_mode() {
  local lbrulejson
  local priority
  local num_priorities

  if ! lbrulejson=$(lb_get_rule_json); then
    return 1
  fi
  priority=$(jq -r '.Priority' <<< "$lbrulejson")
  num_priorities=$(wc -l <<< "$priority" | tr -d " ")
  if [[ -z $priority || $num_priorities != "1" ]]; then
    debug "$lbrulejson"
    error "Error detecting weblogic lb rule priority"
    return 1
  fi
  if ((priority < LB_RULE_MAINTENANCE_PRIORITY)); then
    echo "maintenance mode disabled"
  else
    echo "maintenance mode enabled"
  fi
}

lb_get_target_group_arn() {
  local lbrulejson
  local targetgrouparns

  if ! lbrulejson=$(lb_get_rule_json); then
    return 1
  fi
  targetgrouparns=$(jq -r '.Actions[] | select(.Type == "forward").TargetGroupArn' <<< "$lbrulejson" | grep "$LB_BACKEND_PORT")
  num_targetgrouparns=$(wc -l <<< "$targetgrouparns" | tr -d " ")
  if [[ -z $targetgrouparns || $num_targetgrouparns != "1" ]]; then
    debug "$lbrulejson"
    error "Error detecting backend target group arn"
    return 1
  fi
  echo "$targetgrouparns"
}

lb_get_target_group_health() {
  local arn
  local json
  local healthy_ec2s

  if ! arn=$(lb_get_target_group_arn); then
    return 1
  fi

  debug "aws elbv2 describe-target-health --target-group-arn '$arn'"
  json=$(aws elbv2 describe-target-health --target-group-arn "$arn" --no-cli-pager)
  healthy_ec2s=$(jq -r '.TargetHealthDescriptions[] | select(.TargetHealth.State == "healthy").Target.Id' <<< "$json")
  if [[ -z $healthy_ec2s ]]; then
    echo 0
  else
    wc -l <<< "$healthy_ec2s" | tr -d " "
  fi
}

lb_get_target_group_name() {
  local arn
  local targetgroup

  if ! arn=$(lb_get_target_group_arn); then
    return 1
  fi
  targetgroup=$(cut -d/ -f2 <<< "$arn" | cut -d- -f1-4)
  if [[ -z $targetgroup ]]; then
    error "Error extracting target group from arn: $arn"
    return 1
  fi
  echo "$targetgroup"
}

main() {
  set -eo pipefail
  while getopts "de:l:qv" opt; do
      case $opt in
          d)
              DRYRUN=1
              ;;
          e)
              NCR_ENVIRONMENT=${OPTARG}
              ;;
          l)
              LB=${OPTARG}
              ;;
          q)
              PRINT_FQDN_ONLY=1
              ;;
          v)
              VERBOSE=1
              ;;
          :)
              error "Error: option ${OPTARG} requires an argument"
              exit 1
              ;;
          ?)
              error "Invalid option: ${OPTARG}"
              exit 1
              ;;
      esac
  done

  shift $((OPTIND-1))

  if [[ -z $1 ]]; then
    usage
  fi

  if [[ -z $NCR_ENVIRONMENT ]]; then
    set_env_instance_id
    set_env_ncr_environment
  fi
  set_env_variables

  if [[ $1 == "biprws" ]]; then
    set_env_admin_password
    set_env_biprws_logon_token

    if [[ $2 == "server-list" ]]; then
      if ! pages_json=$(biprws_get_pages "https://$ADMIN_URL/biprws/bionbi/server/list"); then
        exit 1
      fi
      pages_tsv=$(jq -sr '.[] | [.title, .status_type, .disabled, .kind, .description] |@tsv' <<< "$pages_json")
      if [[ -z $pages_tsv ]]; then
        error "API returned no servers"
        exit 1
      fi
      shift 2
      output_tsv=$(filter_server_list "$pages_tsv" "$@")
      if ((PRINT_FQDN_ONLY == 1)); then
        echo "$output_tsv" | cut -f1
      else
        echo -e "Title\tStatus\tEnabled\tKind\tDescription"
        echo "$output_tsv"
      fi
    else
      usage
      exit 1
    fi
  elif [[ $1 == "ccm" ]]; then
    set_env_admin_password
    if [[ $2 == "display" ]]; then
      ccm -display
    else
      cmd=$2
      shift 2
      for fqdn; do
        ccm "-$cmd" "$fqdn"
      done
    fi
  elif [[ $1 == "lb" ]]; then
    set_env_lb "$LB"
    if [[ $2 == "maintenance-mode" ]]; then
      if [[ $3 == "enable" ]]; then
        lb_enable_maintenance_mode
      elif [[ $3 == "disable" ]]; then
        lb_disable_maintenance_mode
      elif [[ $3 == "check" ]]; then
        lb_get_maintenance_mode
      else
        usage
        exit 1
      fi
    elif [[ $2 == "get-target-group" ]]; then
      if [[ $3 == "arn" ]]; then
        lb_get_target_group_arn
      elif [[ $3 == "health" ]]; then
        lb_get_target_group_health
      elif [[ $3 == "name" ]]; then
        lb_get_target_group_name
      else
        usage
        exit 1
      fi
    elif [[ $2 == "get-json" ]]; then
      if [[ $3 == "rules" ]]; then
        lb_get_listener_rules_json
      elif [[ $3 == "rule" ]]; then
        lb_get_rule_json
      else
        usage
        exit 1
      fi
    else
      usage
      exit 1
    fi
  else
    usage
    exit 1
  fi
}

main "$@"
