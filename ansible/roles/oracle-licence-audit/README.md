# oracle-licence-audit

## Overview

The `oracle-licence-audit` role collects information required for Oracle licence reviews across Oracle Database and WebLogic environments running on the Modernisation Platform.

The role gathers:

- Oracle database licensing reports
- Oracle Feature Usage and Options/Packs reports
- CPU and vCPU information
- AWS EC2 CPU configuration
- WebLogic ECS cluster vCPU usage
- Consolidated licence summary
- Compressed audit archive

The collected output is uploaded to the configured S3 bucket where it can be reviewed or supplied to Oracle Licensing.

## What is collected

### Database servers

For each Oracle database instance the role collects:

- Oracle ReviewLite report
- Oracle Feature Usage Statistics report
- Oracle Options and Packs usage summary

The role automatically discovers running Oracle databases and determines the appropriate `ORACLE_HOME` from `/etc/oratab`.

### CPU information

For each database server the role collects:

- Oracle `cpuq.sh` hardware audit
- EC2 CPU options (CoreCount and ThreadsPerCore)
- Calculated Oracle processor licence count

### WebLogic

For WebLogic environments the role collects both host-level and cluster-level licensing information.

On WebLogic EC2 instances the role runs the Oracle `cpuq.sh` hardware audit and collects EC2 CPU options. If WebLogic is detected on the host, the generated CPU output filename is suffixed with `_weblogic`.

For ECS-hosted WebLogic environments the role also calculates:

- Running container instances
- Underlying EC2 instance types
- vCPU counts
- Total WebLogic licensing footprint

Only running container instances are included in the ECS cluster licence calculation.

### Summary

After collection has completed, the role generates:

- `oracle_full_summary.txt`
- A ZIP archive containing all collected files
- Uploads the results back to the configured S3 bucket

## Prerequisites

The role expects:

- AWS credentials configured locally (or supplied by GitHub Actions)
- AWS CLI installed
- Access to the target AWS account(s)
- Target EC2 instances accessible through AWS Systems Manager
- SQL*Plus installed on Oracle database servers
- Oracle databases running as the `oracle` user

## Running the audit

The audit can be run either locally from the `modernisation-platform-configuration-management` repository or centrally from the `dso-modernisation-platform-automation` GitHub Actions workflow.

### Running locally

Run from the root of the configuration-management repository.

#### Using `container.sh` (recommended)

Using AWS environment variables:

```bash
./container.sh ansible-playbook site.yml \
  -e force_role=oracle-licence-audit \
  --tags collection
```

Using `aws-vault`:

```bash
./container.sh -v nomis-test ansible-playbook site.yml \
  -e force_role=oracle-licence-audit \
  --tags collection
```

Run only database collection:

```bash
./container.sh -v nomis-test ansible-playbook site.yml \
  -e force_role=oracle-licence-audit \
  --tags collection,databases
```

Run only WebLogic collection:

```bash
./container.sh -v nomis-test ansible-playbook site.yml \
  -e force_role=oracle-licence-audit \
  --tags collection,weblogic
```

Generate the summary only:

```bash
./container.sh -v nomis-test ansible-playbook site.yml \
  -e force_role=oracle-licence-audit \
  --tags summary
```

## Running from GitHub Actions

The preferred way of running audits across multiple applications or environments is via the **Oracle Licence Audit** workflow in the `dso-modernisation-platform-automation` repository.

The workflow checks out this repository and executes:

```bash
ansible-playbook roles/ansible/site.yml \
  -e force_role=oracle-licence-audit
```

The workflow supports two operations:

| Operation | Description |
|----------|-------------|
| **collection** | Collect Oracle Database, CPU and/or WebLogic audit information |
| **summary** | Generate the consolidated summary and ZIP archive |

When running **collection**, the workflow allows the following filters:

| Input | Description |
|------|-------------|
| **applications** | Limit the audit to a specific application, or leave blank for all |
| **environments** | Limit the audit to selected environments |
| **auditLevel** | Run `databases`, `weblogic` or both |
| **target_hostname** | Optionally limit the audit to a specific host |
| **SourceConfigVersion** | Branch, tag or commit of this repository to use |

The workflow automatically selects the appropriate inventory groups for each application and executes the relevant tags.

The **summary** operation runs once against the shared audit S3 bucket and generates the consolidated output.

## Tags

| Tag | Description |
|------|-------------|
| `collection` | Run audit collection |
| `databases` | Audit Oracle databases and CPU information |
| `weblogic` | Audit WebLogic ECS clusters |
| `summary` | Generate consolidated summary and ZIP archive |
| `upload` | Upload collected files to S3 |

## Output

By default, audit results are uploaded to:

```
dependencies/oracle/utils/audit/YYYY-MM/
```

Typical output includes:

```
oracle_full_summary.txt
audit_YYYY-MM-DD.zip
*_ct_cpuq.txt
*_vcpus.txt
ReviewLite*.txt
options_packs_usage_statistics.txt
options_packs_usage_summary.txt
```

## Configuration

The following variables can be overridden if required.

| Variable | Default | Description |
|----------|---------|-------------|
| `audit_dir` | `/tmp/audit` | Local working directory |
| `upload_collection` | `true` | Upload results to S3 |
| `region` | `eu-west-2` | AWS region |
| `bucket_name` | Dependencies bucket | Destination S3 bucket |

## Notes

- The role uses Oracle's supplied `cpuq.sh` utility to collect processor information.
- Database instances are automatically discovered by inspecting running Oracle processes.
- `ORACLE_HOME` is obtained from `/etc/oratab`.
- S3 uploads are encrypted using the bucket's configured KMS key.
- WebLogic licensing is calculated from the vCPUs of the underlying ECS container instances that are currently running.
- Summary generation runs once per environment and produces a consolidated report and ZIP archive.