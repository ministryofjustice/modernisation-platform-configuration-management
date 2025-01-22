#!/bin/bash
# Helper script for starting/stopping BIP environment cleanly
# - use biprws API to retrieve server list
# - use ccm.sh script to retrieve server list / run commands
# - use ec2 tags and env vars to print expected server list
# - update load balancer maintenance mode
#
# Also see pipelines in dso-modernisation-platform-management repo
#
# PREREQ. The script figures out desired server state from tags and
# the configured _SERVER environment variables. Check this actually
# matches the working environment, and adjust the env variables as
# required, e.g. compare ccm output with expected servers
#   $ ./bip_control.sh diff server-list ccm exp
#
# To shutdown environment cleanly as per https://me.sap.com/notes/0002390652:

#0. Enable Maintenance Mode on the LB
#1. Stop the Web Application Server (Tomcat or other) / EC2s.
#2. Disable all services except the Central Management Server, Input File Repository Server and Output File Repository Server.
#3. Wait for 10 minutes.
#4. Stop the Event Servers.
#5. Stop all Job Servers.
#6. Stop all Processing servers (Example: Crystal Processing Servers / Web Intelligence Processing Servers)
#7. Stop the rest of the servers.
#8. Stop SIA
#
# To restart environment cleanly, in reverse order:
#8. Start SIA
#7. Start non-processing/job/event servers
#6. Start all Processing servers (Example: Crystal Processing Servers / Web Intelligence Processing Servers)
#5. Start all Job Servers.
#4. Start the Event Servers.
#3. Wait for 10 minutes (n/a - not required on start up)
#2. Enable all services
#1. Start the Web Application Servers (Tomcat or other) / EC2s.
#0. Disable Maintenance Mode on the LB

DRYRUN=0
VERBOSE=0
LBS=
FORMAT=default
LOGPREFIX=
APPLICATION_NAME="{{ application }}"
AWS_ENVIRONMENT="{{ aws_environment }}"
CCM_SH="{{ sap_bip_installation_directory }}/sap_bobj/ccm.sh"
CCM_WAIT_FOR_CMD_ENABLED=0
CCM_WAIT_FOR_CMD_TIMEOUT_SECS=60
STAGE3_WAIT_SECS=600

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
APS.Connectivity,Running,Enabled
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
  -f default|json|fqdn|sia  Display in given format, if applicable, default is $FORMAT
  -l public|private|admin   Select LB endpoint(s)
  -3 wait_secs              Pipeline stage 3 wait time, default is $STAGE3_WAIT_SECS
  -v                        Enable verbose debug
  -p <logprefix>            Prefix all log lines with given prefix
  -w                        Wait for CCM command

Where <cmd>:
  biprws     server-list                [<servers>]          - use BIPRWS API to print BIP given servers
  ccm        server-list                [<servers>]          - use ccm.sh to display servers
  ccm        disable|enable             <fqdns>              - use ccm.sh to enable/disable server(s) by fqdn
  ccm        managedstart|managedstop   <fqdns>              - use ccm.sh to start/stop server(s) by fqdn
  ccm        start|stop                 <fqdns>              - use ccm.sh to start/stop sia(s) by fqdn
  exp        server-list                [<servers>]          - derive expected server-list from environment
  lb         maintenance-mode           enable|disable|check - enable, disable or check maintenance mode on given LB
  lb         get-target-group           arn|health|name      - get target group ARN, health or name on given LB
  lb         get-json                   rules|rule           - debug lb json
  diff       server-list                <a> <b> [<servers>]  - run a diff against two server-lists, a/b one of biprws,ccm,exp
  pipeline   start|stop                 all|012345678        - start and stop cleanly, run all steps or just selected

Where <servers> are space separated and can be:
  <fqdn>     - fqdn of server name, e.g. ppncrcms1.AdaptiveJobServer
  all        - all servers
  cms        - all CentralManagementServer servers
  cms1       - this server, or primary cms
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
    echo "${LOGPREFIX}DEBUG: $*" >&2
  fi
}

dryrun_debug() {
  if ((DRYRUN != 0)); then
    echo "${LOGPREFIX}DRYRUN: $*" >&2
  elif ((VERBOSE != 0)); then
    echo "${LOGPREFIX}DEBUG: $*" >&2
  fi
}

log() {
  echo "${LOGPREFIX}$*"
}

error() {
  echo "${LOGPREFIX}$*" >&2
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
  ADMIN_LB_NAME=public-lb
  ADMIN_LB_RULE_MAINTENANCE_PRIORITY=999
  ADMIN_LB_PORT=443
  ADMIN_LB_BACKEND_PORT=7010
  CMS_SIA=${INSTANCE_NAME//-/}

  BASE_URL=reporting.$(echo "$APPLICATION_NAME" | cut -d- -f1 | tr -s "[:upper:]" "[:lower:]").service.justice.gov.uk
  if [[ -n $AWS_ENVIRONMENT && $AWS_ENVIRONMENT != "production" ]]; then
    BASE_URL="$AWS_ENVIRONMENT.$BASE_URL"
  fi

  if [[ $SAP_ENVIRONMENT == pp || $SAP_ENVIRONMENT == pd ]]; then
    ADMIN_URL=admin.$BASE_URL
    PUBLIC_LB_URL=$BASE_URL
    PRIVATE_LB_URL=int.$BASE_URL
    if [[ -z $LBS ]]; then
      LBS="private public admin"
    fi
  else
    ADMIN_URL=$SAP_ENVIRONMENT.$BASE_URL
    PUBLIC_LB_URL=$SAP_ENVIRONMENT.$BASE_URL
    PRIVATE_LB_URL=$SAP_ENVIRONMENT-int.$BASE_URL
    if [[ -z $LBS ]]; then
      LBS="private public"
    fi
  fi
}

set_env_instance_id() {
  debug "curl -sS -X PUT http://169.254.169.254/latest/api/token"
  token=$(curl -sS -m 2 -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 3600")
  INSTANCE_ID=$(curl -sS -m 2 -H "X-aws-ec2-metadata-token: $token" http://169.254.169.254/latest/meta-data/instance-id)
}

set_env_sap_environment() {
  debug "aws ec2 describe-tags --filters 'Name=resource-id,Values=$INSTANCE_ID' 'Name=key,Values=$APPLICATION_NAME-environment'"
  SAP_ENVIRONMENT=$(aws ec2 describe-tags --no-cli-pager --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=$APPLICATION_NAME-environment" --output text | cut -f5)
  if [[ -z $SAP_ENVIRONMENT ]]; then
    error "Unable to retrieve $APPLICATION_NAME-environment tag"
    return 1
  fi
}

set_env_instance_name() {
  debug "aws ec2 describe-tags --filters 'Name=resource-id,Values=$INSTANCE_ID' 'Name=key,Values=Name'"
  INSTANCE_NAME=$(aws ec2 describe-tags --no-cli-pager --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=Name" --output text | cut -f5)
  if [[ -z $INSTANCE_NAME ]]; then
    error "Unable to retrieve Name tag"
    return 1
  fi
}

get_ec2_server_names() {
  local json
  local ec2id
  local ec2ids

  debug "aws ec2 describe-instances --filters 'Name=tag:$APPLICATION_NAME-environment,Values=$SAP_ENVIRONMENT' 'Name=tag:server-type,Values=$1'"
  if ! json=$(aws ec2 describe-instances --no-cli-pager --filters "Name=tag:$APPLICATION_NAME-environment,Values=$SAP_ENVIRONMENT" "Name=tag:server-type,Values=$1"); then
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
  if ! CMS_EC2_NAMES=$(get_ec2_server_names "*-bip-cms"); then
    return 1
  fi
  if ! APP_EC2_NAMES=$(get_ec2_server_names "*-bip-app"); then
    return 1
  fi
  if ! WEB_EC2_NAMES=$(get_ec2_server_names "*-web"); then
    return 1
  fi
  if ! WEBADMIN_EC2_NAMES=$(get_ec2_server_names "*-webadmin"); then
    return 1
  fi
  if [[ -z $APP_EC2_NAMES && -z $CMS_EC2_NAMES ]]; then
    error "Error retrieving EC2 names with *-bip-cms and *-bip-app server-type tags"
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
  elif [[ $1 == "admin" ]]; then
    if [[ $ADMIN_URL == "$PUBLIC_LB_URL" ]]; then
      error "No specific admin endpoint for this environment"
      return 1
    fi
    LB_NAME=$ADMIN_LB_NAME
    LB_RULE_MAINTENANCE_PRIORITY=$ADMIN_LB_RULE_MAINTENANCE_PRIORITY
    LB_PORT=$ADMIN_LB_PORT
    LB_BACKEND_PORT=$ADMIN_LB_BACKEND_PORT
    LB_URL=$ADMIN_URL
  else
    error "Unexpected lb '$1', expected public or private"
    return 1
  fi
}

set_env_admin_password() {
  debug "aws secretsmanager get-secret-value --secret-id /sap/bip/$SAP_ENVIRONMENT/passwords --query SecretString --output text"
  ADMIN_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "/sap/bip/$SAP_ENVIRONMENT/passwords" --query SecretString --output text | jq -r ".Administrator")
  if [[ -z $ADMIN_PASSWORD || $ADMIN_PASSWORD == 'null' ]]; then
    error "Unable to retrieve Administrator password from '/sap/bip/$SAP_ENVIRONMENT/passwords' secret"
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
  if ! jq -e . >/dev/null 2>&1 <<<"$token_json"; then
    error "Logon API returned non-json output, LB might be in maintenance mode"
    return 1
  fi
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
  elif [[ $filter == "cms1" ]]; then
    grep $flags "$CMS_SIA.CentralManagementServer" <<< "$list"
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
  debug "ccm.sh $* -username Administrator -password xxx"
  if [[ ! -x "$CCM_SH" ]]; then
    error "Error ccm.sh script not found: $CCM_SH"
    return 1
  fi
  "$CCM_SH" "$@" -username Administrator -password "$ADMIN_PASSWORD"
}

ccm_display_to_tsv() {
  local l
  local server_name
  local state
  local enabled
  local host_name
  local pid
  local description

  (
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
  ) | sort -uf
}

get_expected_servers() {
  local ec2
  local server

  (
    if [[ -n $APP_EC2_NAMES ]]; then
      if [[ -z $CMS_EC2_NAMES ]]; then
        error "Error finding EC2 names with *-bip-cms server-type tag, only got *-bip-app server-type: $APP_EC2_NAMES"
        return 1
      fi
      for ec2 in $APP_EC2_NAMES; do
        for server in $APP_SERVERS; do
          echo "${ec2//-/}.$server"
        done
      done
      for ec2 in $CMS_EC2_NAMES; do
        for server in $CMS_SERVERS; do
          echo "${ec2//-/}.$server"
        done
        if [[ $ec2 == *1 && $CMS_EC2_NAMES == *\ * ]]; then
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
    elif [[ -n $CMS_EC2_NAMES ]]; then
      ec2=$CMS_EC2_NAMES
      for server in $CMS_ONLY_SERVERS; do
        echo "${ec2//-/}.$server"
      done
    else
      error "Error finding EC2s with *-bip-cms and *-bip-app server-type tags"
      return 1
    fi
  ) | sed 's/,/\t/g' | sort -uf
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
      log "maintenance mode disabled"
    fi
  else
    log "maintenance mode already disabled"
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
      log "maintenance mode enabled"
    fi
  else
    log "maintenance mode already enabled"
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
    echo "disabled"
  else
    echo "enabled"
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
  elif [[ $1 == "display" ]]; then
    if [[ $FORMAT != "default" ]]; then
      error "$FORMAT format unsupported with ccm commands"
      return 1
    fi
    ccm -display
  else
    if [[ $FORMAT != "default" ]]; then
      error "$FORMAT format unsupported with ccm commands"
      return 1
    fi
    cmd=$1
    shift
    fqdns=$*
    for fqdn in $fqdns; do
      if ((DRYRUN == 0)); then
        ccm "-$cmd" "$fqdn"
      else
        log "DRYRUN: ccm -$cmd $fqdn"
      fi
    done
    if ((CCM_WAIT_FOR_CMD_ENABLED == 1 && DRYRUN == 0)); then
      debug "Waiting for cmds to complete..."
      start_epoch_secs=$(date +%s)
      while true; do
        output=$(ccm -display)
        ccm_display_tsv=$(ccm_display_to_tsv "$output")
        success=1
        end_epoch_secs=$(date +%s)
        for fqdn in $fqdns; do
          if [[ $cmd == "managedstart" ]]; then
            result=$(filter_server_list "$ccm_display_tsv" "$fqdn" "-Running")
          elif [[ $cmd == "managedstop" ]]; then
            result=$(filter_server_list "$ccm_display_tsv" "$fqdn" "-Stopped")
          elif [[ $cmd == "disable" ]]; then
            result=$(filter_server_list "$ccm_display_tsv" "$fqdn" "-Disabled")
          elif [[ $cmd == "enable" ]]; then
            result=$(filter_server_list "$ccm_display_tsv" "$fqdn" "-Enabled")
          elif [[ $cmd == "stop" ]]; then
            result=$(filter_server_list "$ccm_display_tsv" "$fqdn")
          else
            error "ccm command $cmd does not support wait -w option"
            return 1
          fi
          if [[ -n $result ]]; then
            if ((end_epoch_secs - start_epoch_secs < CCM_WAIT_FOR_CMD_TIMEOUT_SECS)); then
              debug "Still waiting for: $result"
            else
              error "Timed out waiting for: $result"
            fi
            success=0
          fi
        done
        if ((success == 1)); then
          break
        elif ((end_epoch_secs - start_epoch_secs >= CCM_WAIT_FOR_CMD_TIMEOUT_SECS)); then
          return 1
        fi
        sleep 5
      done
    fi
  fi
}

do_exp() {
  set -eo pipefail

  set_env_ec2_names

  if [[ $1 == "server-list" ]]; then
    shift
    exp_display_tsv=$(get_expected_servers)
    output_tsv=$(filter_server_list "$exp_display_tsv" "$@")
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

get_server_list() {
  local cmd

  set -eo pipefail

  cmd=$1
  shift
  if [[ $cmd == "biprws" ]]; then
    do_biprws "server-list" "$@"
  elif [[ $cmd == "ccm" ]]; then
    do_ccm "server-list" "$@"
  elif [[ $cmd == "exp" ]]; then
    do_exp "server-list" "$@"
  else
    error "Expected one of biprws, ccm, exp; got '$cmd'"
    return 1
  fi
}

do_diff() {
  local a
  local b

  set -eo pipefail

  if [[ $1 == "server-list" ]]; then
    if (( $# < 3 )); then
      usage
      return 1
    fi
    cmd1=$2
    cmd2=$3
    shift 3

    a=$(get_server_list "$cmd1" "$@" | cut -f1,2,3)
    b=$(get_server_list "$cmd2" "$@" | cut -f1,2,3)

    debug "A: $a"
    debug "B: $b"
    diff <(echo "$a") <(echo "$b")
  else
    usage
    return 1
  fi
}

do_pipeline() {
  set -eo pipefail

  if [[ $FORMAT != "default" ]]; then
    error "$FORMAT format unsupported with pipeline commands"
    return 1
  fi

  tmp_filename="/tmp/.bip_control.$(whoami).disabled"
  set_env_ec2_names
  num_web_ec2s=$(wc -w <<< "$WEB_EC2_NAMES" | tr -d " ")
  num_webadmin_ec2s=$(wc -w <<< "$WEBADMIN_EC2_NAMES" | tr -d " ")
  exp_display_tsv=$(get_expected_servers)
  exp_display_tsv_status=$(cut -f1,2 <<< "$exp_display_tsv")
  exp_display_tsv_enabled=$(cut -f1,3 <<< "$exp_display_tsv")

  if [[ $2 == "all" || $2 =~ [0-1] ]]; then
    set_env_lb "private"
    lb_private_maintenance_mode=$(lb_get_maintenance_mode)
    lb_private_target_group_health=$(lb_get_target_group_health)
    set_env_lb "public"

    lb_public_maintenance_mode=$(lb_get_maintenance_mode)
    lb_admin_maintenance_mode="not-applicable"
    lb_admin_target_group_health=0
    if (( num_webadmin_ec2s > 0 )); then
      set_env_lb "admin" || exitcode=$?
      if [[ exitcode -ne 0 ]]; then
        error "Unable to set admin LB env event though webadmin EC2s present"
        return 1
      fi
      lb_admin_maintenance_mode=$(lb_get_maintenance_mode)
      lb_admin_target_group_health=$(lb_get_target_group_health)
    fi
  fi

  CCM_WAIT_FOR_CMD_ENABLED=1
  ccm_exitcode=0
  if [[ $2 == "all" || $2 =~ [2-7] ]]; then
    set_env_admin_password
    ccm_output=$(ccm -display) || ccm_exitcode=$?
    ccm_output_tsv=$(ccm_display_to_tsv "$ccm_output" | sed 's/Running with Errors/Running/g')
    ccm_output_tsv_status=$(cut -f1,2 <<< "$ccm_output_tsv")
    ccm_output_tsv_enabled=$(cut -f1,3 <<< "$ccm_output_tsv")
    set +o pipefail
    target_tsv_status=$(diff <(echo "$ccm_output_tsv_status") <(echo "$exp_display_tsv_status") | grep '> ' | cut -d' ' -f2)
    target_tsv_enabled=$(diff <(echo "$ccm_output_tsv_enabled") <(echo "$exp_display_tsv_enabled") | grep '> ' | cut -d' ' -f2)
    set -o pipefail
  fi

  if [[ $2 == "all" || $2 == *8* ]]; then
    debug "systemctl is-active sapbobj"
    sapbobj_isactive=$(systemctl is-active sapbobj || true)
  fi

  if [[ $1 == "start" ]]; then
    if [[ $2 == "all" || $2 == *8* ]]; then
      if [[ $sapbobj_isactive != "active" || $ccm_exitcode -ne 0 ]]; then
        if ((DRYRUN == 0)); then
          error "please run 'systemctl start sapbobj' on $CMS_EC2_NAMES $APP_EC2_NAMES first"
          return 1
        else
          log "DRYRUN:   please run 'systemctl start sapbobj' on $CMS_EC2_NAMES $APP_EC2_NAMES"
        fi
      else
        log "complete: sapbobj services are started on $CMS_EC2_NAMES $APP_EC2_NAMES"
      fi
    fi
    if [[ $2 == "all" || $2 == *7* ]]; then
      step7=$(filter_server_list "$target_tsv_status" all -event -job -processing +Running | cut -f1 | xargs)
      if [[ -n $step7 ]]; then
        log "running:  './bip_control.sh -w ccm managedstart $step7'"
        do_ccm managedstart "$step7"
      else
        log "skipping: all non-event/job/processing servers already started"
      fi
    fi
    if [[ $2 == "all" || $2 == *6* ]]; then
      step6=$(filter_server_list "$target_tsv_status" processing +Running | cut -f1 | xargs)
      if [[ -n $step6 ]]; then
        log "running:  './bip_control.sh -w ccm managedstart $step6'"
        do_ccm managedstart "$step6"
      else
        log "skipping: all processing servers already started"
      fi
    fi
    if [[ $2 == "all" || $2 == *5* ]]; then
      step5=$(filter_server_list "$target_tsv_status" job +Running | cut -f1 | xargs)
      if [[ -n $step5 ]]; then
        log "running:  './bip_control.sh -w ccm managedstart $step5'"
        do_ccm managedstart "$step5"
      else
        log "skipping: all processing servers already started"
      fi
    fi
    if [[ $2 == "all" || $2 == *4* ]]; then
      step4=$(filter_server_list "$target_tsv_status" event +Running | cut -f1 | xargs)
      if [[ -n $step4 ]]; then
        log "running:  './bip_control.sh -w ccm managedstart $step4'"
        do_ccm managedstart "$step4"
      else
        log "skipping: all processing servers already started"
      fi
    fi
    if [[ $2 == "all" || $2 == *3* ]]; then
      log "skipping: 'sleep' not required on start up"
    fi
    if [[ $2 == "all" || $2 == *2* ]]; then
      step2=$(filter_server_list "$target_tsv_enabled" Enabled | cut -f1 | xargs)
      if [[ -n $step2 ]]; then
        log "running:  './bip_control.sh -w ccm enable $step2'"
        do_ccm enable "$step2"
      else
        log "skipping: all expected services already enabled"
      fi
    fi
    if [[ $2 == "all" || $2 == *1* ]]; then
      if (( lb_private_target_group_health != num_web_ec2s || lb_admin_target_group_health != num_webadmin_ec2s )); then
        if ((DRYRUN == 0)); then
          error "please run 'systemctl start sapbobj' on $WEB_EC2_NAMES $WEBADMIN_EC2_NAMES first"
          return 1
        else
          log "DRYRUN:   please run 'systemctl start sapbobj' on $WEB_EC2_NAMES $WEBADMIN_EC2_NAMES"
        fi
      else
        log "skipping: sapbobj services are already started on $WEB_EC2_NAMES $WEBADMIN_EC2_NAMES"
      fi
    fi
    if [[ $2 == "all" || $2 == *0* ]]; then
      if [[ $lb_private_maintenance_mode == "enabled" || $lb_public_maintenance_mode == "enabled" || $lb_admin_maintenance_mode == "enabled" ]]; then
        if [[ $lb_private_maintenance_mode == "enabled" ]]; then
          log "running:  './bip_control.sh -l private lb maintenance-mode disable'"
          set_env_lb "private"
          lb_disable_maintenance_mode
        fi
        if [[ $lb_public_maintenance_mode == "enabled" ]]; then
          log "running:  './bip_control.sh -l public lb maintenance-mode disable'"
          set_env_lb "public"
          lb_disable_maintenance_mode
        fi
        if [[ $lb_admin_maintenance_mode == "enabled" ]]; then
          log "running:  './bip_control.sh -l admin lb maintenance-mode disable'"
          set_env_lb "admin"
          lb_disable_maintenance_mode
        fi
      else
        log "complete: all lb maintenance modes are disabled"
      fi
    fi
  elif [[ $1 == "stop" ]]; then

    if [[ $2 == "all" || $2 == *0* ]]; then
      if [[ $lb_private_maintenance_mode == "disabled" || $lb_public_maintenance_mode == "disabled" || $lb_admin_maintenance_mode == "disabled" ]]; then
        if [[ $lb_private_maintenance_mode == "disabled" ]]; then
          log "running:  './bip_control.sh -l private lb maintenance-mode enable'"
          set_env_lb "private"
          lb_enable_maintenance_mode
        fi
        if [[ $lb_public_maintenance_mode == "disabled" ]]; then
          log "running:  './bip_control.sh -l public lb maintenance-mode enable'"
          set_env_lb "public"
          lb_enable_maintenance_mode
        fi
        if [[ $lb_admin_maintenance_mode == "disabled" ]]; then
          log "running:  './bip_control.sh -l admin lb maintenance-mode enable'"
          set_env_lb "admin"
          lb_enable_maintenance_mode
        fi
      else
        log "complete: all lb maintenance modes are enabled"
      fi
    fi
    if [[ $2 == "all" || $2 == *1* ]]; then
      if (( lb_private_target_group_health != 0 || lb_admin_target_group_health != 0 )); then
        if ((DRYRUN == 0)); then
          error "please run 'systemctl stop sapbobj' on $WEB_EC2_NAMES $WEBADMIN_EC2_NAMES first"
        else
          log "DRYRUN:   please run 'systemctl stop sapbobj' on $WEB_EC2_NAMES $WEBADMIN_EC2_NAMES"
        fi
      else
        log "skipping: sapbobj services are already stopped on $WEB_EC2_NAMES $WEBADMIN_EC2_NAMES"
      fi
    fi
    if [[ $2 == "all" || $2 == *2* ]]; then
      step2=$(filter_server_list "$ccm_output_tsv_enabled" all -cms -frs -Disabled | cut -f1 | xargs)
      if [[ -n $step2 ]]; then
        log "running:  './bip_control.sh -w ccm disable $step2'"
        do_ccm disable "$step2"
        date +%s > "$tmp_filename"
      else
        log "skipping: all services are already disabled apart from CMS and FRS"
      fi
    fi
    if [[ $2 == "all" || $2 == *3* ]]; then
      if ((DRYRUN == 0)); then
        if [[ -e "$tmp_filename" ]]; then
          now_epoch=$(date +%s)
          disabled_epoch=$(head -1 "$tmp_filename")
          n=$(( ((STAGE3_WAIT_SECS+59)-(now_epoch-disabled_epoch))/60 ))
          if ((n <= 0 || n > 15)); then
            log "skipping: not sleeping as disabled services timestamp older than wait timeout ${STAGE3_WAIT_SECS}s (n=$n minutes)"
            n=0
          else
            for i in $(seq 1 $n); do
              log "running:  [$i/$n]: 'sleep 60' waiting for clean stop"
              sleep 60
            done
          fi
        else
          log "skipping: not sleeping as disabled services timestamp not found"
        fi
      else
        log "DRYRUN:   'sleep ${STAGE3_WAIT_SECS}' for clean stop"
      fi
    fi
    if [[ $2 == "all" || $2 == *4* ]]; then
      step4=$(filter_server_list "$ccm_output_tsv_status" event -Stopped | cut -f1 | xargs)
      if [[ -n $step4 ]]; then
        log "running:  './bip_control.sh -w ccm managedstop $step4'"
        do_ccm managedstop "$step4"
      else
        log "skipping: all event servers are already stopped"
      fi
    fi
    if [[ $2 == "all" || $2 == *5* ]]; then
      step5=$(filter_server_list "$ccm_output_tsv_status" job -Stopped | cut -f1 | xargs)
      if [[ -n $step5 ]]; then
        log "running:  './bip_control.sh -w ccm managedstop $step5'"
        do_ccm managedstop "$step5"
      else
        log "skipping: all job servers are already stopped"
      fi
    fi
    if [[ $2 == "all" || $2 == *6* ]]; then
      step6=$(filter_server_list "$ccm_output_tsv_status" processing -Stopped | cut -f1 | xargs)
      if [[ -n $step6 ]]; then
        log "running:  './bip_control.sh -w ccm managedstop $step6'"
        do_ccm managedstop "$step6"
      else
        log "skipping: all processing servers are already stopped"
      fi
    fi
    if [[ $2 == "all" || $2 == *7* ]]; then
      step7=$(filter_server_list "$ccm_output_tsv_status" all -event -job -processing -cms1 -Stopped | cut -f1 | xargs)
      if [[ -n $step7 ]]; then
        log "running:  './bip_control.sh -w ccm managedstop $step7'"
        do_ccm managedstop "$step7"
      else
        log "skipping: all non-event/job/processing servers are already stopped"
      fi
    fi
    if [[ $2 == "all" || $2 == *8* ]]; then
      step8=$(filter_server_list "$ccm_output_tsv_status" all -cms1 -Stopped | cut -f1 | cut -d. -f1 | sort -u | xargs)
      if [[ -n $step8 || $sapbobj_isactive == "active" ]]; then
        if [[ -n $step8 ]]; then
          log "running:  './bip_control.sh -w ccm stop $step8'"
          do_ccm managedstop "$step7"
        fi
        if [[ $sapbobj_isactive == "active" || $ccm_exitcode -eq 0 ]]; then
          if ((DRYRUN == 0)); then
            error "run 'systemctl stop sapbobj' on $CMS_EC2_NAMES $APP_EC2_NAMES first"
          else
            log "DRYRUN:   please run 'systemctl stop sapbobj' on $CMS_EC2_NAMES $APP_EC2_NAMES"
          fi
        fi
      else
        log "skipping: sapbobj services are already stopped on $CMS_EC2_NAMES $APP_EC2_NAMES"
      fi
    fi
  else
    usage
  fi
}

do_lb() {
  set -eo pipefail

  if [[ -z $LBS ]]; then
    error "No LB specified"
    return 1
  fi

  num_lbs=$(wc -w <<< "$LBS" | tr -d " ")
  for LB in $LBS; do
    set_env_lb "$LB"
    if ((num_lbs > 1)); then
      echo -n "$LB: "
    fi

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
 done
}

main() {
  set -eo pipefail
  while getopts "3:df:l:p:vw" opt; do
      case $opt in
          3)
              STAGE3_WAIT_SECS=${OPTARG}
              ;;
          d)
              DRYRUN=1
              ;;
          l)
              LBS=${OPTARG}
              ;;
          f)
              FORMAT=${OPTARG}
              ;;
          p)
              LOGPREFIX=${OPTARG}
              ;;
          v)
              VERBOSE=1
              ;;
          w)
              CCM_WAIT_FOR_CMD_ENABLED=1
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

  set_env_instance_id
  set_env_sap_environment
  set_env_instance_name
  set_env_variables

  if [[ $1 == "biprws" ]]; then
    shift
    do_biprws "$@"
  elif [[ $1 == "ccm" ]]; then
    shift
    do_ccm "$@"
  elif [[ $1 == "exp" ]]; then
    shift
    do_exp "$@"
  elif [[ $1 == "diff" ]]; then
    shift
    do_diff "$@"
  elif [[ $1 == "pipeline" ]]; then
    shift
    do_pipeline "$@"
  elif [[ $1 == "lb" ]]; then
    shift
    do_lb "$@"
  else
    usage
    exit 1
  fi
}

main "$@"
