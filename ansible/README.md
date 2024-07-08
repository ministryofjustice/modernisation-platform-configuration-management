# Modernisation Platform Ansible Configuration

## Introduction

For provisioning and in-life management of EC2 instances. AMI configuration ansible
belongs in [modernisation-platform-ami-builds] (https://github.com/ministryofjustice/modernisation-platform-ami-builds).

Please include a README.md for each role.

## Using ansible to provision an EC2 instance

Use `user_data` to provide a cloud init or shell script which runs
ansible. See nomis ansible template scripts in [modernisation-platform-environments](https://github.com/ministryofjustice/modernisation-platform-environments/tree/main/terraform/environments/nomis/templates/) for an example. This relies on
tags to identify which roles to run.

## Running ansible locally on a linux EC2 instance

The `ansible-script` role installs a wrapper script ansible.sh in the /root/ directory.
Use this to run ansible within a virtual environment pulling in appropriate group_vars.
For example:

```
/root/ansible.sh site.yml --tags ec2patch
```

## Installing on Mac

Choose which version of python and ansible-core to use. The below
example uses python3.9 and ansible-core 2.12 as this is compatible with some
older OS.

This can be problematic. If you run into issues:
- uninstall all existing python3.9 / ansible installations via brew. `brew list` and `brew uninstall ansible` for example
- check no other installation of python3.9 `which python3.9`. If there is delete it.
- install python via brew `brew install python@3.9`
- check `which python3.9` matches the recent installation
- ensure certs are up to date `brew reinstall ca-certificates`
- list all pip packages `python3.9 -m pip list`
- uninstall any existing ansible installs `python3.9 -m pip uninstall ansible`
- install ansible `python3.9 -m pip install ansible-core==2.12`
- install ansible requirements as per step 4 below

1. Optionally install a specific python versoin

```
brew install python@3.9
```

Ensure CA certs are up-to-date

```
brew install ca-certificates
```

2. Install ansible using pip

```
python3.9 -m pip install ansible-core==2.12
```

Check ansible is in current path and correct version using `ansible --version`.
Check for matching core and python versions.

```
ansible [core 2.12.0]
  python version = 3.9.6 (default, Nov 10 2023, 13:38:27) [Clang 15.0.0 (clang-1500.1.0.2.5)]
```

3. Optionally update PATH

If ansible is not in the current path, or is showing an unexpected version,
check where the installation by using uninstall option. Don't proceed with
the uninstall when given the option.

```
python3.9 -m pip uninstall ansible-core

Found existing installation: ansible-core 2.12.0
Uninstalling ansible-core-2.12.0:
  Would remove:
    /opt/homebrew/bin/ansible
...
Proceed (Y/n)? n
```

Ensure the directory containing ansible binaries is in your path, e.g.
Add following to  `~/.bash_profile`

```
PATH=/opt/homebrew/bin:$PATH
```

Open a new terminal window and re-check Step 2.

4. Install requirements

```
python3.9 -m pip install -r requirements.txt
ansible-galaxy role install -r requirements.yml
ansible-galaxy collection install -r requirements.yml
```

If this `ansible-galaxy collection install -r requirements.yml` fails, try:

```
ansible-galaxy collection install -r requirements.rhel6.yml
```

Check boto and botocore installed:

```
python3.9 -m pip list
```

5. Configure local environment

5.1. Paste in credentials

Sign into relevant AWS account via [AWS SSO](https://moj.awsapps.com/start/) and select access keys.
Use Option 1: Set AWS environment variables.
Click to copy these commands and paste into terminal.

Check you can access the dynamic inventory

```
no_proxy="*" ansible-inventory  --graph
```

This should show a list of EC2s in the account grouped by various tags. Run `ansible-playbook` like this:

```
no_proxy="*" ansible-playbook site.yml --check
```

5.2. Use aws-vault

Use `aws-vault` to avoid having to paste in AWS environment variables:

- ensure aws CLI installed and aws accounts are configured
- install aws-vault `brew install aws-vault`

The first time you use aws-vault, you will be prompted to enter a keychain password
to protect the keychain. You will need to enter this password from time to time
when using aws-vault. Note you can adjust the password timeout in KeyChain settings.

```
export no_proxy="*"
aws-vault exec nomis-development -- ansible-inventory  --graph
```

## Running ansible against an EC2 instance post build

A generic [site.yml](/ansible/site.yml) is provided with dynamic inventories
under [hosts/](/ansible/hosts/) folder. This creates groups based of the following
tags:

- ami
- os-type
- environment-name
- server-type

There are separate inventories depending on whether the EC2 is stood up
as part of an autoscaling group or as an individual instance. In an autoscaling
group, all instances will have the same tags, so the instance id is used as the
hostname rather than the Name tag.

Use tags to differentiate between provisioning and in-life operational
tasks. For example, "ec2provision" and "ec2patch" respectively.

Ansible tasks are executed on ec2 instances via AWS Session Manager, so you must have [awscli](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-mac.html#cliv2-mac-install-cmd) installed in addition to the Session Manager [plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html#install-plugin-macos-signed). The target ec2 instance must also have [ssm-agent](https://docs.aws.amazon.com/systems-manager/latest/userguide/ssm-agent.html) installed. You do not need to have an account on the remote ec2 instance in order to connect.

The `ansible_connection` variable is set to use the `community.aws.aws_ssm` plugin in [group_vars/aws_ec2.yml](/ansible/group_vars/aws_ec2.yml). The `aws_ec2` group is the default group for all instances that are obtained from dynamic inventory.

Ensure you have set your AWS credentials as environment variables or setup your `~/.aws/credentials` accordingly before attempting to run ansible. Note that at the time of writing, it does not seem possible to run Ansible with credentials obtained from `aws sso login`. Temporary credentials can be obtained from https://moj.awsapps.com/start#/

You may encounter an error similar to `ERROR! A worker was found in a dead state`. Apparently this is a Python issue and the workaround is to set an env:

```
export no_proxy='*'
```

The Session Manager plugin requires that an S3 bucket is specified as one of the connection variables. Set this within an environment specific variable, for example [group_vars/environment_name_nomis_test.yml](/ansible/group_vars/environment_name_nomis_test.yml)

Define the list of roles to run on each type of server under an server-type specific variable. For example [group_vars/server_type_nomis_db.yml](/ansible/group_vars/server_type_nomis_db.yml)

```
---
roles_list:
  - collectd
  - amazon-cloudwatch-agent
```

Run ansible

```
export no_proxy="*"

# Run against all hosts in check mode
ansible-playbook site.yml --check

# Limit to a particular host/group
ansible-playbook site.yml --limit bastion

# Limit to a particular role
ansible-playbook site.yml -e "role=amazon-cloudwatch-agent"

# Run locally (the comma after localhost is important)
ansible-playbook site.yml --connection=local -i localhost, -e "target=localhost" -e "@group_vars/server_type_nomis_db.yml" --check
```

To run against multiple environments, use aws-vault, e.g.
```
export no_proxy="*"
for account in nomis-development nomis-test; do
  aws-vault exec $account -- ansible-playbook site.yml -e role=users-and-groups --limit os_type_linux
done
```

## Gotchas for RHEL6

The ansible.builtin.yum task misbehaves when running from local MacOS on a RHEL6 server.
Run ansible locally on the server instead.  Example error message when running on MacOS:

```
TASK [amazon-cloudwatch-agent : Install amazon-cloudwatch-agent] **********************************************************************************************
fatal: [xxx]: FAILED! => {"changed": false, "msg": "ansible-core requires a minimum of Python2 version 2.7 or Python3 version 3.5. Current version: 2.6.6 (r266:84292, May 31 2023, 09:01:24) [GCC 4.4.7 20120313 (Red Hat 4.4.7-23)]"}
```

The `galaxy.ansible.com` recent updates have broken collection installation on RHEL6.
Use requirements.rhel6.yml instead.  Example error:

```
# [WARNING]: Skipping Galaxy server https://galaxy.ansible.com/api/. Got an unexpected error when getting available versions of collection amazon.aws:
# '/api/v3/plugin/ansible/content/published/collections/index/amazon/aws/versions/'
# ERROR! Unexpected Exception, this is probably a bug: '/api/v3/plugin/ansible/content/published/collections/index/amazon/aws/versions/'
```
