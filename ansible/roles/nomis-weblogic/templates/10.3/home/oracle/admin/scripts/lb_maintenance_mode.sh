#!/bin/bash
LBNAME=private-lb
URL={{ nomis_configs[nomis_environment].url }}
PORT=443
MAINTENANCE_PRIORITY=999
FLAG=$1
export PATH="$PATH:/usr/local/bin"

set -e

if [[ $FLAG != "enable" && $FLAG != "disable" && $FLAG != "check" ]]; then
  echo "Usage: $0 enable|disable|check"
  echo
  echo "Enable or disable maintenance mode by adjusting load balancer rule priority for $URL"
  exit 1
fi

echo "Retrieving load balancer config using aws elbv2 commands" >&2
lbarn=$(aws elbv2 describe-load-balancers | jq -r '.LoadBalancers[] | select(.LoadBalancerName=="'$LBNAME'").LoadBalancerArn')
if [[ -z $lbarn ]]; then
  echo "Error retriving load balancer details for $LBNAME" >&2
  exit 1
fi

listenerarn=$(aws elbv2 describe-listeners --load-balancer-arn "$lbarn" | jq -r '.Listeners[] | select(.Port=='$PORT').ListenerArn')
if [[ -z $listenerarn ]]; then
  echo "Error retrieving load balancer HTTPS $PORT listener for $LBNAME" >&2
  exit 1
fi

maintenancerulejson=$(aws elbv2 describe-rules --listener-arn "$listenerarn" | jq '.Rules[] | select(.Conditions | length != 0) | select(.Conditions[].Values[] | contains("'$URL'")) | select(.Priority == "'$MAINTENANCE_PRIORITY'")')
if [[ -z $maintenancerulejson ]]; then
  echo "Error retrieving maintenance rule priority == $MAINTENANCE_PRIORITY with URL $URL" >&2
  exit 1
fi

rulejson=$(aws elbv2 describe-rules --listener-arn "$listenerarn" | jq '.Rules[] | select(.Conditions | length != 0) | select(.Conditions[0].Values[] | contains("'$URL'")) | select(.Priority != "'$MAINTENANCE_PRIORITY'")')
rulearn=$(echo "$rulejson" | jq -r .RuleArn)
priority=$(echo "$rulejson" | jq -r .Priority)
if [[ -z $rulearn || -z $priority ]]; then
  echo "Error retrieving load balancer rule for $URL" >&2
  exit 1
fi
if [[ $(echo "$priority" | wc -l) != 1 ]]; then
  echo "Multiple matching rules for URL $URL" >&2
  exit 1
fi

if (( priority < 1000 )); then
  if [[ $FLAG == "enable" ]]; then
    newpriority=$((priority + 1000))
    echo "Enabling maintenance mode by change rule priority $priority -> $newpriority"
    aws elbv2 set-rule-priorities --rule-priorities "RuleArn=$rulearn,Priority=$newpriority" --output text > /dev/null
    echo "DONE"
  elif [[ $FLAG == "disable" ]]; then
    echo "Maintenance mode already disabled"
  else
    echo "Maintenance mode is disabled"
  fi
else
  if [[ $FLAG == "enable" ]]; then
    echo "Maintenance mode already enabled"
  elif [[ $FLAG == "disable" ]]; then
    newpriority=$((priority - 1000))
    echo "Disabling maintenance mode by change rule priority $priority -> $newpriority"
    aws elbv2 set-rule-priorities --rule-priorities "RuleArn=$rulearn,Priority=$newpriority" --output text > /dev/null
    echo "DONE"
  else
    echo "Maintenance mode is enabled"
  fi
fi
