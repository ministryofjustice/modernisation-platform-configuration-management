#!/bin/bash

# Set AWS region
AWS_REGION="eu-west-2"

# Function to check endpoint and send metric
check_endpoint() {
    endpoint="$1"
    expected_code="$2"
    
    start_time=$(date +%s%N)
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$endpoint" -m 10)
    end_time=$(date +%s%N)
    
    duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds

    if [ "$http_code" -eq "$expected_code" ]; then
        status=0
        echo "Success: $endpoint returned $http_code (expected $expected_code)"
    else
        status=1
        echo "Failure: $endpoint returned $http_code (expected $expected_code)"
    fi

    # Send metrics to CloudWatch
    aws cloudwatch put-metric-data \
        --region "$AWS_REGION" \
        --namespace "EndpointMonitoring" \
        --metric-data \
        "[
            {
                \"MetricName\": \"EndpointStatus\",
                \"Dimensions\": [{\"Name\": \"Endpoint\",\"Value\": \"$endpoint\"}],
                \"Value\": $status,
                \"Unit\": \"Count\"
            },
            {
                \"MetricName\": \"ResponseTime\",
                \"Dimensions\": [{\"Name\": \"Endpoint\",\"Value\": \"$endpoint\"}],
                \"Value\": $duration,
                \"Unit\": \"Milliseconds\"
            }
        ]"
}

# List of endpoints to check
check_endpoint "https://google.com" 200 # for testing
check_endpoint "http://r1.csr.service.justice.gov.uk:7770/isps/index.html?2057" 200
check_endpoint "https://onr.oasys.az.justice.gov.uk/InfoViewApp" 302

echo "Endpoint checks completed."
