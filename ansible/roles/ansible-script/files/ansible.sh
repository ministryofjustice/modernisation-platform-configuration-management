#!/bin/bash
# Don't set set -u as ansible activate script fails with it on RHEL6
set -eo pipefail

branch="main"
ansible_repo="modernisation-platform-configuration-management"
ansible_repo_basedir="ansible"

run_ansible() {
  export PATH=/usr/local/bin:$PATH

  echo "ansible_repo:         ${ansible_repo}"
  echo "ansible_repo_basedir: ${ansible_repo_basedir}"
  echo "ansible_args:         $@"
  echo "branch:               $branch"

  if [[ -z ${ansible_repo} ]]; then
    echo "ansible_repo not defined, not installing any ansible" >&2
    exit 0
  fi

  if ! command -v aws > /dev/null; then
    echo "aws cli must be installed, not installing any ansible" >&2
    exit 0
  fi

  if ! command -v git > /dev/null; then
    echo "git must be installed, not installing any ansible" >&2
    exit 0
  fi

  echo "# Retrieving API Token"
  token=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

  echo "# Retrieving Instance ID"
  instance_id=$(curl -sS -H "X-aws-ec2-metadata-token: $token" -v http://169.254.169.254/latest/meta-data/instance-id)

  echo "# Retrieving tags using aws cli"
  IFS=$'\n'
  tags=($(aws ec2 describe-tags --filters "Name=resource-id,Values=$instance_id" "Name=key,Values=Name,os-type,ami,server-type,environment-name" --output=text))
  unset IFS

  # clone ansible roles and playbook
  ansible_dir=/root/ansible
  cd $ansible_dir
  if [[ ! -d $ansible_dir/${ansible_repo} ]]; then
    echo "# Cloning ${ansible_repo} into $ansible_dir using branch=$branch"
    git clone "https://github.com/ministryofjustice/${ansible_repo}.git"
    cd $ansible_dir/${ansible_repo}
    git checkout "$branch"
  else
    cd $ansible_dir/${ansible_repo}
    git pull
    git checkout "$branch"
  fi
  cd $ansible_dir

  # find the group_var yaml files
  ansible_group_vars=
  for ((i=0; i<${#tags[@]}; i++)); do
    tag=(${tags[i]})
    group=$(echo "${tag[1]}_${tag[4]}" | tr [:upper:] [:lower:] | sed "s/-/_/g")
    if [[ "${tag[1]}" == "Name" ]]; then
      ansible_group_vars="$ansible_group_vars --extra-vars ec2_name=${tag[4]}"
    elif [[ -e $ansible_dir/${ansible_repo}/${ansible_repo_basedir}/group_vars/$group.yml ]]; then
      ansible_group_vars="$ansible_group_vars --extra-vars @group_vars/$group.yml"
    elif [[ -e $ansible_dir/${ansible_repo}/${ansible_repo_basedir}/group_vars/$group/ansible.yml ]]; then
      ansible_group_vars="$ansible_group_vars --extra-vars @group_vars/$group/ansible.yml"
    else
      echo "Could not find group_vars $group yml"
      exit 1
    fi
    if [[ "${tag[1]}" == "environment-name" ]]; then
      aws_environment=$(echo ${tag[4]} | rev | cut -d- -f1 | rev)
      application=$(echo ${tag[4]} | rev | cut -d- -f2- | rev)
      ansible_group_vars="$ansible_group_vars --extra-vars aws_environment=$aws_environment --extra-vars application=$application"
    fi
  done

  # set python version
  if [[ $(which python3.9 2> /dev/null) ]]; then
    python=$(which python3.9)
  elif [[ $(which python3.6 2> /dev/null) ]]; then
    python=$(which python3.6)
  else
    echo "Python3.9/3.6 not found"
    exit 1
  fi
  echo "# Using python: $python"

  # activate virtual environment
  update=0
  if [[ ! -d $ansible_dir/python-venv ]]; then
    mkdir $ansible_dir/python-venv
    update=1
  fi
  cd $ansible_dir/python-venv
  $python -m venv ansible
  source ansible/bin/activate
  if [[ $update == 1 ]]; then
    $python -m pip install --upgrade pip
    if [[ "$python" =~ 3.6 ]]; then
      $python -m pip install wheel
      $python -m pip install cryptography==2.3
      export LC_ALL=en_US.UTF-8
      $python -m pip install ansible-core==2.11.12
    else
      $python -m pip install ansible==6.0.0
    fi

    # install requirements in virtual env
    echo "# Installing ansible requirements"
    cd $ansible_dir/${ansible_repo}/${ansible_repo_basedir}
    $python -m pip install -r requirements.txt
    ansible-galaxy role install -r requirements.yml
    ansible-galaxy collection install -r requirements.yml
  fi

  # run ansible (comma after localhost deliberate)
  cd $ansible_dir/${ansible_repo}/${ansible_repo_basedir}
  echo "# Execute ansible $@ $ansible_group_vars ..."
  ansible-playbook $@ $ansible_group_vars \
   --connection=local \
   --inventory localhost, \
   --extra-vars "ansible_python_interpreter=$python" \
   --extra-vars "target=localhost" \
   --become

  echo "# Deactivate: ansible_dir/${ansible_repo}/${ansible_repo_basedir}"
  deactivate
}

run_ansible $@
