#!/bin/bash

# This script contains functions to stop and start ec2s and RDS instances based on the provided tag criteria.

# Function to stop EC2 instances with a specific tag
stop_ec2_instances() {
  TAG_KEY=$1
  TAG_VALUE=$2
  REGION=$3
  aws ec2 describe-instances \
    --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" "Name=instance-state-name,Values=running" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text --region $REGION > output.txt 2>&1
  INSTANCE_IDS=$(cat output.txt)
  if [ -n "$INSTANCE_IDS" ]; then
    aws ec2 stop-instances --instance-ids $INSTANCE_IDS --region $REGION > /dev/null 2>&1
    echo "Stopped EC2 instances: $INSTANCE_IDS"
  else
    echo "No running EC2 instances found with tag ${TAG_KEY}=${TAG_VALUE}"
  fi
}

# Function to start EC2 instances with a specific tag
start_ec2_instances() {
  TAG_KEY=$1
  TAG_VALUE=$2
  REGION=$3
  aws ec2 describe-instances \
    --filters "Name=tag:${TAG_KEY},Values=${TAG_VALUE}" "Name=instance-state-name,Values=stopped" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text --region $REGION > output.txt 2>&1
  INSTANCE_IDS=$(cat output.txt)
  if [ -n "$INSTANCE_IDS" ]; then
    aws ec2 start-instances --instance-ids $INSTANCE_IDS --region $REGION > /dev/null 2>&1
    echo "Started EC2 instances: $INSTANCE_IDS"
  else
    echo "No stopped EC2 instances found with tag ${TAG_KEY}=${TAG_VALUE}"
  fi
}

# Function to stop RDS instances with a specific tag
stop_rds_instances() {
  TAG_KEY=$1
  TAG_VALUE=$2
  REGION=$3
  aws rds describe-db-instances \
    --query "DBInstances[?DBInstanceStatus == 'available' && contains(TagList[?Key=='${TAG_KEY}'].Value, '${TAG_VALUE}')].DBInstanceIdentifier" \
    --output text --region $REGION > output.txt 2>&1
  DB_INSTANCE_IDENTIFIERS=$(cat output.txt)
  if [ -n "$DB_INSTANCE_IDENTIFIERS" ]; then
    for DB_INSTANCE_IDENTIFIER in $DB_INSTANCE_IDENTIFIERS; do
      aws rds stop-db-instance --db-instance-identifier $DB_INSTANCE_IDENTIFIER --region $REGION > /dev/null 2>&1
      echo "Stopped RDS instance: $DB_INSTANCE_IDENTIFIER"
    done
  else
    echo "No available RDS instances found with tag ${TAG_KEY}=${TAG_VALUE}"
  fi
}

# Function to start RDS instances with a specific tag
start_rds_instances() {
  TAG_KEY=$1
  TAG_VALUE=$2
  REGION=$3
  aws rds describe-db-instances \
    --query "DBInstances[?DBInstanceStatus == 'stopped' && contains(TagList[?Key=='${TAG_KEY}'].Value, '${TAG_VALUE}')].DBInstanceIdentifier" \
    --output text --region $REGION > output.txt 2>&1
  DB_INSTANCE_IDENTIFIERS=$(cat output.txt)
  if [ -n "$DB_INSTANCE_IDENTIFIERS" ]; then
    for DB_INSTANCE_IDENTIFIER in $DB_INSTANCE_IDENTIFIERS; do
      aws rds start-db-instance --db-instance-identifier $DB_INSTANCE_IDENTIFIER --region $REGION > /dev/null 2>&1
      echo "Started RDS instance: $DB_INSTANCE_IDENTIFIER"
    done
  else
    echo "No stopped RDS instances found with tag ${TAG_KEY}=${TAG_VALUE}"
  fi
}

# Main script actions
ACTION=$1
TAG_KEY=$2
TAG_VALUE=$3
REGION=$4

case $ACTION in
  stop_ec2)
    stop_ec2_instances $TAG_KEY $TAG_VALUE $REGION
    ;;
  stop_rds)
    stop_rds_instances $TAG_KEY $TAG_VALUE $REGION
    ;;
  start_ec2)
    start_ec2_instances $TAG_KEY $TAG_VALUE $REGION
    ;;
  start_rds) 
    start_rds_instances $TAG_KEY $TAG_VALUE $REGION
    ;;
  *)
    echo "Usage: $0 {stop_ec2|stop_rds|start_ec2|start_rds} tag_key tag_value aws_region"
    exit 1
    ;;
esac