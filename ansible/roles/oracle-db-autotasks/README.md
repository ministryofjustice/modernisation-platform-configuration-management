# hmpps-oracle-database-autotasks
Management of Oracle Database Autotasks.
This project has a dependecy on:
https://github.com/ministryofjustice/hmpps-env-configs

### Purpose
This repo contains an Ansible Role which may be used to Reschedule and enable/disable Oracle Autotasks.
This would typically be used in the circumstances:
1. Reschedule Autotask Maintenance Windows to avoid periods of downtime (for example when AWS auto stop-start has been implemented)
2. Disable unused features in lower environments (e.g. auto sql advisor where not licenced)

This role may be used either:
1. With a standalone job to change the Autotasks on an existing database (https://github.com/ministryofjustice/delius-manual-deployments/operations/oracle_autotasks)
2. Within the bootstrap of a new Oracle host (https://github.com/ministryofjustice/hmpps-delius-core-oracledb-bootstrap/tasks/main.yml)

## Environment configurations
Configuration information is provided in https://github.com/ministryofjustice/hmpps-env-configs/{environment}/ansible/group_vars for each environment

The dictionary variable database_autotasks defines which of the 3 Oracle Autotasks are enabled or disabled.

database_autotasks:
      sql_tuning_advisor: enabled | disabled
      auto_space_advisor: enabled | disabled
      auto_optimizer_stats_collection: enabled | disabled

If this variable does not exist an entry is not specified then the default is used (which is 'enabled' for current versions of Oracle).

The dictionary variable autotask_windows defines the start time and duration (in minutes) of the Autotask maintenance windows

autotask_windows:
        weekday:
                start_time: "06:20"
                duration_mins: 30

Currently only the element 'weekday' is supported as current AWS auto stop-start implementations do not include environments running at weekends.   This may be expanded in future if there is a requirement.

If this variable does not exist then the default is used (which is '22:00' for 240 minutes for current versions of Oracle).


### Structure
The repo contains standard Ansible role layout.


## GitHub Actions

An action to delete the branch after merge has been added.
Also an action that will tag when branch is merged to master
See https://github.com/anothrNick/github-tag-action

```
Bumping

Manual Bumping: Any commit message that includes #major, #minor, or #patch will trigger the respective version bump. If two or more are present, the highest-ranking one will take precedence.

Automatic Bumping: If no #major, #minor or #patch tag is contained in the commit messages, it will bump whichever DEFAULT_BUMP is set to (which is minor by default).

Note: This action will not bump the tag if the HEAD commit has already been tagged.
```

## Release / Deployments

The new process will include the addition of deploying a known version of this code using a tag from the git repo.
After the code is tested, code reviewed the merge of the feature branch to master will trigger the GitHub action resulting in git tag creation.
These tags can be progressed through the environments towards Production by specifying the tag to deploy.

The tag value is retrieved from AWS SSM Parameter Store. See https://github.com/ministryofjustice/delius-versions
The version retrieved from the AWS SSM Parameter Store is set by updating the tag value in the map `hmpps-delius-core-terraform` in `config/020-delius-core.tfvars` for the environment.

### Jenkins file

This jenkinsfile has two parameters (not to be confused with AWS SSM Parameters)
- CONFIG_BRANCH
- DCORE_BRANCH

This has been used to specify the branch to use in place of the default `master` branch. Going forward the default will be the Git tag or branch specified in the AWS SSM Parameter Store. However the option to override will still be available for development, debugging and hotfix situations.

*psuedo code*

```
if ("aws ssm parameter version" not empty and "DCORE_BRANCH" not defaultValue)
  set "delius core version" to "aws ssm parameter version"
else
  set "delius core version" to "DCORE_BRANCH"
else
  error
```
