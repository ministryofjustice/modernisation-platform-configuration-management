# Modernisation Platform Ansible Configuration

## Introduction

For provisioning and in-life management of EC2 instances. AMI configuration ansible
belongs in [modernisation-platform-ami-builds] (https://github.com/ministryofjustice/modernisation-platform-ami-builds).

Please include a README.md for each role.

## Using ansible to provision an EC2 instance

Use `user_data` to provide a cloud init or shell script which runs
ansible. See nomis ansible template scripts in [modernisation-platform-environments](https://github.com/ministryofjustice/modernisation-platform-environments/tree/main/terraform/environments/nomis/templates/) for an example. This relies on
tags to identify which roles to run.

## Running ansible against an EC2 instance post build

A generic [site.yml](/ansible/site.yml) is provided with dynamic inventories
under [hosts/](/ansible/hosts/) folder. This creates groups based of the following
tags:

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
  - node-exporter
```

Run ansible

```
# Run against all hosts in check mode
ansible-playbook site.yml --check

# Limit to a particular host/group
ansible-playbook site.yml --limit bastion

# Limit to a particular role
ansible-playbook site.yml -e "role=node-exporter"

# Run locally (the comma after localhost is important)
ansible-playbook site.yml --connection=local -i localhost, -e "target=localhost" -e "@group_vars/server_type_nomis_db.yml" --check
```
