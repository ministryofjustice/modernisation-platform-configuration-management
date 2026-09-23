#!/bin/bash
set -e

PROFILE=""
IMAGE="ansible-2.13.13"
BUILD_IMAGE=0

while getopts "6rsv:" opt; do
  case ${opt} in
    6 )
      IMAGE="ansible-2.11.12"
      ;;
    r )
      BUILD_IMAGE=1
      ;;
    s)
      export ANSIBLE_PRIVATE_KEY_FILE=/dev/shm/ansible_private_key_file
      ;;
    v )
      PROFILE=$OPTARG
      ;;
    \? )
      echo "Usage: $0 [-v <aws-profile>] [command...]"
      echo "Where: "
      echo " command        : specify a command and args (e.g. ansible-inventory --graph)"
      echo " -6             : use container compatible with RHEL6 instances"
      echo " -r             : force rebuild of image"
      echo " -s             : enable ssh"
      echo " -v aws-profile : dynamically set aws-profile permissions via aws-vault"
      echo "If no command specified, drop into interactive shell"
      exit 1
      ;;
  esac
done

if command -v podman &> /dev/null; then
  ENGINE="podman"
elif command -v docker &> /dev/null; then
  ENGINE="docker"
else
  echo "ERROR: Neither podman nor docker was found on your system."
  exit 1
fi

if [ "$ENGINE" = "podman" ]; then
  # Set up a temporary directory for podman to use, since it uses /var/tmp by default which will fill up quickly in a container environment. This is a workaround.
  export TMPDIR="${TMPDIR:-/tmp/podman}"
  export TMP="$TMPDIR"
  export TEMP="$TMPDIR"
  mkdir -p "$TMPDIR"
fi

DOCKERFILE="Dockerfile.$IMAGE"

# Calculate a hash of the Dockerfile so we can detect changes
DOCKERFILE_HASH=$(sha256sum "$DOCKERFILE" | awk '{print $1}')

if ! $ENGINE image inspect "$IMAGE" &> /dev/null; then
  BUILD_IMAGE=1
else
  IMAGE_DOCKERFILE_HASH=$($ENGINE image inspect "$IMAGE" \
    --format '{{ index .Config.Labels "ansible.dockerfile.hash" }}' 2>/dev/null || true)

  if [[ "$DOCKERFILE_HASH" != "$IMAGE_DOCKERFILE_HASH" ]]; then
    echo "# $DOCKERFILE has changed - rebuilding image"
    BUILD_IMAGE=1
  fi
fi

if [[ $BUILD_IMAGE -eq 1 ]]; then
  echo "# Building $IMAGE using $ENGINE..."
  $ENGINE build --label "ansible.dockerfile.hash=$DOCKERFILE_HASH" -t $IMAGE -f Dockerfile.$IMAGE .
fi

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
    -e ANSIBLE_PRIVATE_KEY_FILE \
    $IMAGE $CMD
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
    -e ANSIBLE_PRIVATE_KEY_FILE \
    $IMAGE $CMD
fi
