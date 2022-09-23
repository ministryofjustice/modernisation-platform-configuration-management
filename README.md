# Modernisation Platform Configuration Management
[![repo standards badge](https://img.shields.io/badge/dynamic/json?color=blue&style=for-the-badge&logo=github&label=MoJ%20Compliant&query=%24.data%5B%3F%28%40.name%20%3D%3D%20%22modernisation-platform-configuration-management%22%29%5D.status&url=https%3A%2F%2Foperations-engineering-reports.cloud-platform.service.justice.gov.uk%2Fgithub_repositories)](https://operations-engineering-reports.cloud-platform.service.justice.gov.uk/github_repositories#modernisation-platform-configuration-management "Link to report")

## About this repository

This is the Ministry of Justice [Modernisation Platform team](https://github.com/orgs/ministryofjustice/teams/modernisation-platform)'s repository for configuration management of the ec2 infrastructure hosted on the Modernisation Platform.

Initially, this repository will contain ansible code used by the Digital Studio Operations. However, in the future it will work as a library of configuration code shared within all the teams that use the Modernisation Platform. Other configuration management tools and technologies used within the platform should also be stored in this repository.

For more information on the Modernisation Platform please see the [user guidance](https://user-guide.modernisation-platform.service.justice.gov.uk).

## Repository structure

At the moment, ansible is the only configuration management tool used in this repository and therefore it contains `ansible` directory.
When a new tool is introduced, a new directory should be created for that tool.

`ansible` directory should store all the ansible code that is common (e.g. roles that can be reused)

`teams` directory should store the code that is team specfic only (e.g. roles that are specific to one team only, ansible playbooks)

## How to use this repository

The code in this repository should work as a library and should be called outside of this repository.
