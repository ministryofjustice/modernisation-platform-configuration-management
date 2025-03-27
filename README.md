# Modernisation Platform Configuration Management

[![Standards Icon]][Standards Link] [![Format Code Icon]][Format Code Link] [![Scorecards Icon]][Scorecards Link] [![SCA Icon]][SCA Link]

## About this repository

This is the Ministry of Justice [Modernisation Platform team](https://github.com/orgs/ministryofjustice/teams/modernisation-platform)'s repository for configuration management of the ec2 infrastructure hosted on the Modernisation Platform.

Initially, this repository will contain ansible code used by the Digital Studio Operations. However, in the future it will work as a library of configuration code shared within all the teams that use the Modernisation Platform. Other configuration management tools and technologies used within the platform should also be stored in this repository.

For more information on the Modernisation Platform please see the [user guidance](https://user-guide.modernisation-platform.service.justice.gov.uk).

## Repository structure

At the moment, ansible is the only configuration management tool used in this repository and therefore it contains `ansible` directory.
When a new tool is introduced, a new directory should be created for that tool.

`ansible` directory should store all the ansible code that is common (e.g. roles that can be reused)

`teams` directory should store the code that is team specfic only (e.g. roles that are specific to one team only, ansible playbooks)

## ⚠️ RHEL6 Compatibility

If you locally execute roles that use the ansible yum modules against remote RHEL6 instance, then you may encounter error messages like below

```
fatal: [i-00a2ec208cf0b4455]: FAILED! => {"changed": false, "msg": "ansible-core requires a minimum of Python2 version 2.7 or Python3 version 3.5. Current version: 2.6.6 (r266:84292, Jun 11 2019, 11:01:44) [GCC 4.4.7 20120313 (Red Hat 4.4.7-23)]"}
```

A workaround for this is to install ansible-core 2.12 on your local machine e.g. `pip install ansible-core==2.12`

## How to use this repository

The code in this repository should work as a library and should be called outside of this repository.

[Standards Link]: https://github-community.service.justice.gov.uk/repository-standards/modernisation-platform-configuration-management "Repo standards badge."
[Standards Icon]: https://github-community.service.justice.gov.uk/repository-standards/api/modernisation-platform-configuration-management/badge
[Format Code Icon]: https://img.shields.io/github/actions/workflow/status/ministryofjustice/modernisation-platform-configuration-management/format-code.yml?labelColor=231f20&style=for-the-badge&label=Formate%20Code
[Format Code Link]: https://github.com/ministryofjustice/modernisation-platform-configuration-management/actions/workflows/format-code.yml
[Scorecards Icon]: https://img.shields.io/github/actions/workflow/status/ministryofjustice/modernisation-platform-configuration-management/scorecards.yml?branch=main&labelColor=231f20&style=for-the-badge&label=Scorecards
[Scorecards Link]: https://github.com/ministryofjustice/modernisation-platform-configuration-management/actions/workflows/scorecards.yml
[SCA Icon]: https://img.shields.io/github/actions/workflow/status/ministryofjustice/modernisation-platform-configuration-management/code-scanning.yml?branch=main&labelColor=231f20&style=for-the-badge&label=Secure%20Code%20Analysis
[SCA Link]: https://github.com/ministryofjustice/modernisation-platform-configuration-management/actions/workflows/code-scanning.yml
