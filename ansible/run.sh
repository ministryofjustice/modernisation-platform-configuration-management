#!/bin/bash
set -e

if command -v podman &> /dev/null; then
  ENGINE="podman"
elif command -v docker &> /dev/null; then
  ENGINE="docker"
else
  echo "Error: Neither podman nor docker was found on your system."
  exit 1
fi

if ! $ENGINE image inspect mac-ansible &> /dev/null; then
  echo "# Building mac-ansible using $ENGINE..."
  $ENGINE build -t mac-ansible .
fi

PROFILE=""

while getopts "v:" opt; do
  case ${opt} in
    v )
      PROFILE=$OPTARG
      ;;
    \? )
      echo "Usage: $0 [-v <aws-profile>] [command...]"
      echo "Where: "
      echo " command        : specify a command and args (e.g. ansible-inventory --graph)"
      echo " -v aws-profile : dynamically set aws-profile permissions via aws-vault"
      echo "If no command specified, drop into interactive shell"
      exit 1
      ;;
  esac
done

shift $((OPTIND -1))
if [ $# -eq 0 ]; then
  CMD="/bin/bash"
else
  CMD="$@"
fi

if [ -n "$PROFILE" ]; then
  echo "# Executing via aws-vault profile: $PROFILE (using $ENGINE)"
  
  aws-vault exec "$PROFILE" -- $ENGINE run --rm -it \
    -v "$(pwd)":/ansible:Z \
    -e AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY \
    -e AWS_SESSION_TOKEN \
    -e AWS_SECURITY_TOKEN \
    mac-ansible $CMD
else
  echo "# Executing with local AWS variables (using $ENGINE)"
  
  $ENGINE run --rm -it \
    -v "$(pwd)":/ansible:Z \
    -e AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY \
    -e AWS_SESSION_TOKEN \
    -e AWS_SECURITY_TOKEN \
    -e AWS_PROFILE \
    -e AWS_DEFAULT_REGION \
    mac-ansible $CMD
fi
