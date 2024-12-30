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
PRINT_FQDN_ONLY=0
CCM_SH="{{ sap_bip_installation_directory }}/sap_bobj/ccm.sh"

usage() {
  echo "Usage $0: <opts> <cmd>

Where <opts>:
  -d                     Enable dryrun for maintenance mode commands
  -e <env>               Optionally set nomis-combined-reporting environment, otherwise derive from EC2 tag
  -q                     Just display FQDNs for BIP output
  -v                     Enable verbose debug

Where <cmd>:
  biprws-get-servers-tsv                        - Print all BIP servers using BIPRWS API
  biprws-get-servers-except-cms-frs             - Print BIP all servers apart from CMS and FRS servers
  biprws-get-event-servers                      - Print BIP event servers
  biprws-get-job-servers                        - Print BIP job servers
  biprws-get-processing-servers                 - Print BIP processing servers
  biprws-get-other-servers                      - Print BIP other servers, i.e. not event,job or processing
  ccm-disable       <fqdn server name>          - ccm.sh disable: disable server
  ccm-display                                   - ccm.sh display: display servers
  ccm-enable        <fqdn server name>          - ccm.sh enable: enable server
  ccm-managed-start <fqdn server name>          - cms.sh managed_start: start server
  ccm-managed-stop  <fqdn server name>          - ccm.sh managed_stop: stop server
  ccm-start         <sianame>                   - ccm.sh start: start sia
  ccm-stop          <sianame>                   - ccm.sh stop: stop sia
  lb-enable-maintenance-mode  <private|public>  - Enable maintenance mode on given LB
  lb-disable-maintenance-mode <private|public>  - Disable maintenance mode on given LB
  lb-get-maintenance-mode     <private|public>  - Get maintenance mode enabled state on given LB
  lb-get-target-group-arn     <private|public>  - Get given LB target group ARN
  lb-get-target-group-health  <private|public>  - Get given LB target group health
  lb-get-target-group-name    <private|public>  - Get giben LB target group name
" >&2
  return 1
}

debug() {
  if ((VERBOSE != 0)); then
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
  NCR_ENVIRONMENT=$(aws ec2 describe-tags --filters "Name=resource-id,Values=$INSTANCE_ID" "Name=key,Values=nomis-combined-reporting-environment" --output text | cut -f5)
  if [[ -z $NCR_ENVIRONMENT ]]; then
    error "Unable to retrieve nomis-combined-reporting-environment tag"
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
    error "Unexpected loadbalancer argument '$1', expected public or private"
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

ccm() {
  if (( DRYRUN == 0 )); then
    debug ccm.sh "$@" -username Administrator -password xxx
    if [[ ! -x "$CCM_SH" ]]; then
      error "Could not find $CCM_SH"
      return 1
    fi
    "$CCM_SH" "$@" -username Administrator -password "$ADMIN_PASSWORD"
  else
    echo "Dry Run: ccm.sh " "$@" "-username Administrator -password xxx"
  fi
}

lb_get_listener_rules_json() {
  local lbarn
  local listenerarn

  debug "aws elbv2 describe-load-balancers"
  lbarn=$(aws elbv2 describe-load-balancers | jq -r '.LoadBalancers[] | select(.LoadBalancerName=="'"$LB_NAME"'").LoadBalancerArn')
  if [[ -z $lbarn ]]; then
    error "Error retriving load balancer details for $LB_NAME"
    return 1
  fi
  debug "aws elbv2 describe-listeners --load-balancer-arn '$lbarn'"
  listenerarn=$(aws elbv2 describe-listeners --load-balancer-arn "$lbarn" | jq -r '.Listeners[] | select(.Port=='"$LB_PORT"').ListenerArn')
  if [[ -z $listenerarn ]]; then
    error "Error retrieving load balancer port $LB_PORT listener for $LB_NAME"
    return 1
  fi
  debug "aws elbv2 describe-rules --listener-arn '$listenerarn'"
  aws elbv2 describe-rules --listener-arn "$listenerarn"
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
    error "Duplicate lb rules found for $LB_URL"
    return 1
  fi
  echo "$rules_json"
}

lb_disable_maintenance_mode() {
  local lbrulejson
  local priority
  local num_priorities
  local rulearn

  if ! lbrulejson=$(lb_get_rule_json); then
    return 1
  fi
  rulearn=$(jq -r '.RuleArn' <<< "$lbrulejson")
  priority=$(jq -r '.Priority' <<< "$lbrulejson")
  num_priorities=$(wc -l <<< "$priority" | tr -d " ")
  if [[ -z $priority || $num_priorities != "1" ]]; then
    echo "$lbrulejson" >&2
    echo "Error detecting weblogic lb rule priority $num_priorities" >&2
    return 1
  fi
  if ((priority > LB_RULE_MAINTENANCE_PRIORITY)); then
    newpriority=$((priority - 1000))
    if (( DRYRUN == 0 )); then
      echo "aws elbv2 set-rule-priorities --rule-priorities 'RuleArn=$rulearn,Priority=$newpriority'" >&2
      aws elbv2 set-rule-priorities --rule-priorities "RuleArn=$rulearn,Priority=$newpriority"
    else
      echo "Dry Run: aws elbv2 set-rule-priorities --rule-priorities 'RuleArn=$rulearn,Priority=$newpriority'" >&2
    fi
  else
    echo "maintenance mode already disabled" >&2
  fi
}

lb_enable_maintenance_mode() {
  local lbrulejson
  local priority
  local num_priorities
  local rulearn

  if ! lbrulejson=$(lb_get_rule_json); then
    return 1
  fi
  rulearn=$(jq -r '.RuleArn' <<< "$lbrulejson")
  priority=$(jq -r '.Priority' <<< "$lbrulejson")
  num_priorities=$(wc -l <<< "$priority" | tr -d " ")
  if [[ -z $priority || $num_priorities != "1" ]]; then
    echo "$lbrulejson" >&2
    echo "Error detecting weblogic lb rule priority" >&2
    return 1
  fi
  if ((priority < LB_RULE_MAINTENANCE_PRIORITY)); then
    newpriority=$((priority + 1000))
    if (( DRYRUN == 0 )); then
      echo "aws elbv2 set-rule-priorities --rule-priorities 'RuleArn=$rulearn,Priority=$newpriority'" >&2
      aws elbv2 set-rule-priorities --rule-priorities "RuleArn=$rulearn,Priority=$newpriority"
    else
      echo "Dry Run: aws elbv2 set-rule-priorities --rule-priorities 'RuleArn=$rulearn,Priority=$newpriority'" >&2
    fi
  else
    echo "maintenance mode already enabled" >&2
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
    echo "$lbrulejson" >&2
    echo "Error detecting weblogic lb rule priority" >&2
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
    echo "$lbrulejson" >&2
    echo "Error detecting weblogic target group arn" >&2
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
  json=$(aws elbv2 describe-target-health --target-group-arn "$arn")
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
    echo "Error extracting target group from arn: $arn"
    return 1
  fi
  echo "$targetgroup"
}

main() {
  set -eo pipefail
  while getopts "de:qv" opt; do
      case $opt in
          d)
              DRYRUN=1
              ;;
          e)
              NCR_ENVIRONMENT=${OPTARG}
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

  if [[ $1 == biprws-* ]]; then
    set_env_admin_password
    set_env_biprws_logon_token

    if [[ $1 == biprws-get-* ]]; then
      if ! pages_json=$(biprws_get_pages "https://$ADMIN_URL/biprws/bionbi/server/list"); then
        exit 1
      fi
      pages_tsv=$(jq -sr '.[] | [.title, .status_type, .disabled, .kind, .description] |@tsv' <<< "$pages_json")
      if [[ -n $pages_tsv ]]; then
        if [[ $1 == "biprws-get-servers" ]]; then
          output_tsv="$pages_tsv"
        elif [[ $1 == "biprws-get-servers-except-cms-frs" ]]; then
          output_tsv=$(grep -Ev 'CentralManagementServer|FileRepository' <<< "$pages_tsv")
        elif [[ $1 == "biprws-get-event-servers" ]]; then
          output_tsv=$(grep EventServer <<< "$pages_tsv")
        elif [[ $1 == "biprws-get-job-servers" ]]; then
          output_tsv=$(grep JobServer <<< "$pages_tsv")
        elif [[ $1 == "biprws-get-processing-servers" ]]; then
          output_tsv=$(grep ProcessingServer <<< "$pages_tsv")
        elif [[ $1 == "biprws-get-other-servers" ]]; then
          output_tsv=$(grep -Ev 'EventServer|JobServer|ProcessingServer' <<< "$pages_tsv")
        else
          usage
          exit 1
        fi
        if ((PRINT_FQDN_ONLY == 1)); then
          echo "$output_tsv" | cut -f1 | sort -f
        else
          echo -e "Title\tStatus\tEnabled\tKind\tDescription"
          echo "$output_tsv" | sort -f
        fi
      else
        error "No servers returned"
        exit 1
      fi
    else
      usage
      exit 1
    fi
  elif [[ $1 == ccm-display ]]; then
    set_env_admin_password
    ccm -display
  elif [[ $1 == ccm-* ]]; then
    if [[ -z $2 ]]; then
      usage
      exit 1
    fi
    set_env_admin_password
    cmd=$1
    shift
    for fqdn; do
      if [[ $cmd == "ccm-disable" ]]; then
        ccm -disable "$fqdn"
      elif [[ $cmd == "ccm-enable" ]]; then
        ccm -enable "$fqdn"
      elif [[ $cmd == "ccm-managed-start" ]]; then
        ccm -managedstart "$fqdn"
      elif [[ $cmd == "ccm-managed-stop" ]]; then
        ccm -managedstop "$fqdn"
      elif [[ $cmd == "ccm-start" ]]; then
        ccm -start "$fqdn"
      elif [[ $cmd == "ccm-stop" ]]; then
        ccm -stop "$fqdn"
      else
        usage
        exit 1
      fi
    done
  elif [[ $1 == lb-* ]]; then
    if [[ -z $2 ]]; then
      usage
    fi
    set_env_lb "$2"
    if [[ $1 == "lb-enable-maintenance-mode" ]]; then
      lb_enable_maintenance_mode
    elif [[ $1 == "lb-disable-maintenance-mode" ]]; then
      lb_disable_maintenance_mode
    elif [[ $1 == "lb-get-maintenance-mode" ]]; then
      lb_get_maintenance_mode
    elif [[ $1 == "lb-get-target-group-arn" ]]; then
      lb_get_target_group_arn
    elif [[ $1 == "lb-get-target-group-health" ]]; then
      lb_get_target_group_health
    elif [[ $1 == "lb-get-target-group-name" ]]; then
      lb_get_target_group_name
    elif [[ $1 == "lb-get-listener-rules-json" ]]; then
      lb_get_listener_rules_json
    elif [[ $1 == "lb-get-rule-json" ]]; then
      lb_get_rule_json
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
