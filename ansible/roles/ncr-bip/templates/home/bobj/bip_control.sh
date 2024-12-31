#!/bin/bash
# Helper script for BIP to help start/stop environment cleanly
# - use biprws API to retrieve server list
# - use ccm.sh script to retrieve server list / run commands
# - use ec2 tags to print expected server list
# - update load balancer maintenance mode
#
# To shutdown environment cleanly as per https://me.sap.com/notes/0002390652:
#1. Stop the Web Application Server (Tomcat or other).
#   - enable maintenance mode on LB: 'bip_control.sh lb maintenance mode enable'
#   - run systemctl stop sapbobj on all web servers
#2. Disable all services except the Central Management Server, Input File Repository Server and Output File Repository Server.
#   - grab list via ccm: fqdns=$(bip_control.sh -f fqdn ccm server-list all -cms -frs -Disabled)
#                        bip_control.sh ccm disable $fqdns
#3. Wait for 10 minutes.
#4. Stop the Event Servers.
#   - grab list via ccm: fqdns=$(bip_control.sh -f fqdn ccm server-list event -Stopped)
#                        bip_control.sh ccm managed-stop $fqdns
#5. Stop all Job Servers.
#   - grab list via ccm: fqdns=$(bip_control.sh -f fqdn ccm server-list job -Stopped)
#                        bip_control.sh ccm managed-stop $fqdns
#6. Stop all Processing servers (Example: Crystal Processing Servers / Web Intelligence Processing Servers)
#   - grab list via ccm: fqdns=$(bip_control.sh -f fqdn ccm server-list processing -Stopped)
#                        bip_control.sh ccm managed-stop $fqdns
#7. Stop the rest of the servers.
#   - grab list via ccm: fqdns=$(bip_control.sh -f fqdn ccm server-list all -event -job -processing -Stopped)
#                        bip_control.sh ccm managed-stop $fqdns
#8. Stop SIA.
#   - grab list via ccm: fqdns=$(bip_control.sh -f sia ccm server-list)
#                        bip_control.sh ccm stop $fqdns

DRYRUN=0
VERBOSE=0
LB=private
FORMAT=default
CCM_SH="{{ sap_bip_installation_directory }}/sap_bobj/ccm.sh"

APP_SERVERS="AdaptiveJobServer,Running,Enabled
AdaptiveProcessingServer,Stopped,Disabled
APS.Analysis,Stopped,Disabled
APS.Connectivity,Running,Enabled
APS.Core,Stopped,Disabled
APS.DF,Running,Enabled
APS.Monitoring,Stopped,Disabled
APS.Visualization,Running,Enabled
APS.WebI,Running,Enabled
APS.WebIDSLBridge,Running,Enabled
ConnectionServer,Running,Enabled
WebApplicationContainerServer,Stopped,Disabled
WebIntelligenceProcessingServer,Running,Enabled"

CMS_SERVERS="AdaptiveJobServer,Stopped,Disabled
APS.Auditing,Running,Enabled
APS.Connectivity,Stopped,Disabled
APS.Core,Running,Enabled
APS.Monitoring,Running,Enabled
APS.PromotionManagement,Running,Enabled
APS.Search,Stopped,Disabled
CentralManagementServer,Running,Enabled
ConnectionServer,Stopped,Disabled
EventServer,Running,Enabled
InputFileRepository,Running,Enabled
OutputFileRepository,Running,Enabled
WebApplicationContainerServer,Stopped,Disabled"

CMS_SERVERS_1="APS.Search,Stopped,Disabled"
CMS_SERVERS_2="APS.Search,Running,Enabled"

CMS_ONLY_SERVERS="AdaptiveJobServer,Running,Enabled
AdaptiveProcessingServer,Stopped,Disabled
APS.Analysis,Stopped,Disabled
APS.Auditing,Stopped,Disabled
APS.Connectivity,Running_with_errors,Enabled
APS.Core,Running,Enabled
APS.Data,Stopped,Disabled
APS.DF,Running,Enabled
APS.Monitoring,Running,Enabled
APS.PromotionManagement,Running,Enabled
APS.Search,Stopped,Disabled
APS.Visualization,Running,Enabled
APS.Webi,Running,Enabled
APS.WebIDSLBridge,Running,Enabled
CentralManagementServer,Running,Enabled
ConnectionServer,Running,Enabled
EventServer,Running,Enabled
InputFileRepository,Running,Enabled
OutputFileRepository,Running,Enabled
WebApplicationContainerServer,Stopped,Disabled
WebIntelligenceProcessingServer,Running,Enabled"

usage() {
  echo "Usage $0: <opts> <cmd>

Where <opts>:
  -d                        Enable dryrun for maintenance mode commands
  -e <env>                  Optionally set nomis-combined-reporting environment, otherwise derive from EC2 tag
  -f default|json|fqdn|sia  Display in given format, if applicable, default is $FORMAT
  -l public|private         Select LB to act on, default is $LB
  -v                        Enable verbose debug

Where <cmd>:
  biprws     server-list                [<servers>]          - use BIPRWS API to print BIP given servers
  ccm        server-list                [<servers>]          - use ccm.sh to display servers
  ccm        disable|enable             <fqdns>              - use ccm.sh to enable/disable server(s) by fqdn
  ccm        managed-start|managed-stop <fqdns>              - use ccm.sh to start/stop server(s) by fqdn
  ccm        start|stop                 <fqdns>              - use ccm.sh to start/stop sia(s) by fqdn
  ec2        server-list                [<servers>]          - derive expected server-list from environment
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

get_ec2_server_names() {
  local json
  local ec2id
  local ec2ids

  debug "aws ec2 describe-instances --filters 'Name=tag:nomis-combined-reporting-environment,Values=$NCR_ENVIRONMENT' 'Name=tag:server-type,Values=$1'"
  if ! json=$(aws ec2 describe-instances --no-cli-pager --filters "Name=tag:nomis-combined-reporting-environment,Values=$NCR_ENVIRONMENT" "Name=tag:server-type,Values=$1"); then
    return 1
  fi
  ec2ids=$(jq -r ".Reservations[].Instances[].InstanceId" <<< "$json")
  (
    for ec2id in $ec2ids; do
      if ! jq -r ".Reservations[].Instances[] | select(.InstanceId==\"$ec2id\") | .Tags[] | select(.Key==\"Name\") | .Value" <<< "$json"; then
        return 1
      fi
    done
  ) | xargs
}

set_env_ec2_names() {
  if ! CMS_EC2_NAMES=$(get_ec2_server_names "ncr-bip-cms"); then
    return 1
  fi
  if ! APP_EC2_NAMES=$(get_ec2_server_names "ncr-bip-app"); then
    return 1
  fi
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
    if [[ -n $list ]]; then
      sort -uf <<< "$list"
    fi
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
    if [[ -n $output ]]; then
      sort -uf <<< "$output"
    fi
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

ccm_display_to_tsv() {
  local l
  local server_name
  local state
  local enabled
  local host_name
  local pid
  local description

  server_name=
  while read -r l; do
    if [[ $l =~ ^Server\ Name:\ (.*) ]]; then
      if [[ -n $server_name ]]; then
        echo -e "$server_name\t$state\t$enabled\t$pid\t$description\t$host_name"
      fi
      server_name=${BASH_REMATCH[1]}
      state=
      enabled=
      host_name=
      pid=
      description=
    elif [[ $l =~ State:\ (.*) ]]; then
      state=${BASH_REMATCH[1]}
    elif [[ $l =~ Enabled:\ (.*) ]]; then
      enabled=${BASH_REMATCH[1]}
    elif [[ $l =~ Host\ Name:\ (.*) ]]; then
      host_name=${BASH_REMATCH[1]}
    elif [[ $l =~ PID:\ (.*) ]]; then
      pid=${BASH_REMATCH[1]}
    elif [[ $l =~ Description:\ (.*) ]]; then
      description=${BASH_REMATCH[1]}
    elif [[ -n $l && $l != Description:* ]]; then
      debug "$l"
    fi
  done <<< "$1"
  if [[ -n $server_name ]]; then
    echo -e "$server_name\t$state\t$enabled\t$pid\t$description\t$host_name"
  fi
}

ec2_expected_servers() {
  local ec2
  local server

  (
    if [[ -n $APP_EC2_NAMES ]]; then
      for ec2 in $APP_EC2_NAMES; do
        for server in $APP_SERVERS; do
          echo "${ec2//-/}.$server"
        done
      done
      for ec2 in $APP_CMS_NAMES; do
        for server in $CMS_SERVERS; do
          echo "${ec2//-/}.$server"
        done
        if [[ $ec2 == *1 && $CMS_SERVERS == *\ * ]]; then
          for server in $CMS_SERVERS_1; do
            echo "${ec2//-/}.$server"
          done
        else
          for server in $CMS_SERVERS_2; do
            echo "${ec2//-/}.$server"
          done
        fi
      done
    elif [[ $CMS_EC2_NAMES == *\ * ]]; then
      error "Unsupported configuration, no app servers but multiple cms"
      return 1
    else
      ec2=$CMS_EC2_NAMES
      for server in $CMS_ONLY_SERVERS; do
        echo "${ec2//-/}.$server"
      done
    fi
  ) | sed 's/,/\t/g'
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

do_biprws() {
  set -eo pipefail

  set_env_admin_password
  set_env_biprws_logon_token

  if [[ $1 == "server-list" ]]; then
    shift
    if ! pages_json=$(biprws_get_pages "https://$ADMIN_URL/biprws/bionbi/server/list"); then
      return 1
    fi
    if [[ $FORMAT == "json" ]]; then
      if (( $# != 0 )); then
        error "Cannot use json format with server-list filter"
        return 1
      fi
      echo "$pages_json"
    else
      pages_tsv=$(jq -sr '.[] | [.title, .status_type, .disabled, .server_process_id, .description, .kind, .last_modified] |@tsv' <<< "$pages_json")
      output_tsv=$(filter_server_list "$pages_tsv" "$@")
      if [[ $FORMAT == "fqdn" ]]; then
        echo "$output_tsv" | cut -f1
      elif [[ $FORMAT == "sia" ]]; then
        echo "$output_tsv" | cut -f1 | cut -d. -f1 | sort -u
      elif [[ $FORMAT == "default" ]]; then
        echo -e "FQDN\tStatus\tEnabled\tPID\tDescription\tKind\tLastModified"
        echo "$output_tsv"
      else
        error "Unsupported format $FORMAT"
      fi
    fi
  else
    usage
    return 1
  fi
}

do_ccm() {
  set -eo pipefail

  set_env_admin_password

  if [[ $1 == "server-list" ]]; then
    shift
    output=$(ccm -display)
    ccm_display_tsv=$(ccm_display_to_tsv "$output")
    output_tsv=$(filter_server_list "$ccm_display_tsv" "$@")
    if [[ $FORMAT == "fqdn" ]]; then
      echo "$output_tsv" | cut -f1
    elif [[ $FORMAT == "sia" ]]; then
      echo "$output_tsv" | cut -f1 | cut -d. -f1 | sort -u
    elif [[ $FORMAT == "default" ]]; then
      echo -e "FQDN\tStatus\tEnabled\tPID\tDescription\tHostName"
      echo "$output_tsv"
    else
      error "Unsupported format $FORMAT"
    fi
  else
    if [[ $FORMAT != "default" ]]; then
      error "$FORMAT format unsupported with ccm commands"
      return 1
    fi
    cmd=$1
    shift
    for fqdn; do
      ccm "-$cmd" "$fqdn"
    done
  fi
}

do_ec2() {
  set -eo pipefail

  set_env_ec2_names

  if [[ $1 == "server-list" ]]; then
    shift
    ec2_display_tsv=$(ec2_expected_servers)
    output_tsv=$(filter_server_list "$ec2_display_tsv" "$@")
    if [[ $FORMAT == "fqdn" ]]; then
      echo "$output_tsv" | cut -f1
    elif [[ $FORMAT == "sia" ]]; then
      echo "$output_tsv" | cut -f1 | cut -d. -f1 | sort -u
    elif [[ $FORMAT == "default" ]]; then
      echo -e "FQDN\tStatus\tEnabled"
      echo "$output_tsv"
    else
      error "Unsupported format $FORMAT"
    fi
  else
    usage
    return 1
  fi
}

do_lb() {
  set -eo pipefail

  set_env_lb "$LB"

  if [[ $FORMAT != "default" ]]; then
    error "$FORMAT format unsupported with lb commands"
    return 1
  fi

  if [[ $1 == "maintenance-mode" ]]; then
    if [[ $2 == "enable" ]]; then
      lb_enable_maintenance_mode
    elif [[ $2 == "disable" ]]; then
      lb_disable_maintenance_mode
    elif [[ $2 == "check" ]]; then
      lb_get_maintenance_mode
    else
      usage
      return 1
    fi
  elif [[ $1 == "get-target-group" ]]; then
    if [[ $2 == "arn" ]]; then
      lb_get_target_group_arn
    elif [[ $2 == "health" ]]; then
      lb_get_target_group_health
    elif [[ $2 == "name" ]]; then
      lb_get_target_group_name
    else
      usage
      return 1
    fi
  elif [[ $1 == "get-json" ]]; then
    if [[ $2 == "rules" ]]; then
      lb_get_listener_rules_json
    elif [[ $2 == "rule" ]]; then
      lb_get_rule_json
    else
      usage
      return 1
    fi
  else
    usage
    return 1
  fi
}

main() {
  set -eo pipefail
  while getopts "de:f:l:v" opt; do
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
          f)
              FORMAT=${OPTARG}
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
    shift
    do_biprws "$@"
  elif [[ $1 == "ccm" ]]; then
    shift
    do_ccm "$@"
  elif [[ $1 == "ec2" ]]; then
    shift
    do_ec2 "$@"
  elif [[ $1 == "lb" ]]; then
    shift
    do_lb "$@"
  else
    usage
    exit 1
  fi
}

main "$@"
