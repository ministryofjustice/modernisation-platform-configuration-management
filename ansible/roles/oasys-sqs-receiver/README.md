# Overview

Use this role to install and configure the OASys SQS Message Receiver on an OASys database server.

The role:

- Installs java-1.8.0-openjdk
- Downloads the SqsReceiveMessage release from S3
- Deploys the application files to the server
- Configures permissions required by Oracle
- Installs and configures a systemd service
- Starts and enables the daemon at boot
- Supports deployment of new application releases

The SQS Message Receiver polls an AWS SQS queue, writes messages to files on the database server and makes them available for processing by OASys via Oracle external tables.

# Pre-requisites

Ensure:

- OASys is installed on the database server
- The server has access to AWS Secrets Manager
- The server has access to the S3 bucket containing the SqsReceiveMessage release zip
- The  repository to downlod OpenJDK is configured on the server
- The Oracle user has read/write access to the deployment directory
- Required variables are defined in inventory or group_vars

# Key Variables

| Variable | Description |
|-----------|-------------|
| `oasys_sqs_release_version` | Version of the SqsReceiveMessage release being deployed |
| `oasys_sqs_zip_src` | Name of the release zip file in S3 |
| `oasys_sqs_source_bucket` | S3 path containing the release zip |
| `oasys_sqs_secret_path` | AWS Secrets Manager path used by the daemon |
| `oasys_sqs_poll_interval_seconds` | SQS polling interval in seconds |
| `oasys_sqs_service_name` | Name of the systemd service |

Example:

```yaml
oasys_sqs_release_version: "7.9.1.0"
oasys_sqs_zip_src: "SqsReceiveMessage.zip"
oasys_sqs_secret_path: "/delius_oasys/{{ app_env }}/queue"
oasys_sqs_poll_interval_seconds: 300
```

# Deployment

Deploy the OASys SQS Message Receiver:

```bash

```
 no_proxy="*" ansible-playbook site.yml --limit t2-oasys-db-a -e force_role=oasys-sqs-receiver -e oracle_sid=T2OASYS -e app_env=t2

 #  oracle_sid provided since 2 oasys test databases T2OASYS and T2OASYS2 exist on  t2-oasys-db-a
 #  app_env provided and must match app_env in oasys_sqs_secret_path 

# Updating to a New Release

Upload the new release zip to S3 and update in the group_vars environment file e.g. environment_name_oasys_development.yml:

```yaml
oasys_sqs_release_version: "7.9.1.1"
```

Re-run the role. The existing service will be stopped, the new release deployed and the daemon restarted automatically.

# Service Management

The daemon is installed as a systemd service:

```bash
systemctl status {{ oracle_sid }}-oasys-sqs-receiver
systemctl restart {{ oracle_sid }}-oasys-sqs-receiver
```

Application logs are written to:

```text
/var/log/oasys-sqs-receiver/SqsMessageReceiver.log
```

# Troubleshooting

Verify the daemon is running:

```bash
systemctl status {{ oracle_sid }}-oasys-sqs-receiver
```

Verify Java installation:

```bash

```
/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.492.b09-1.0.1.el8.x86_64/jre/bin/java -version

Review daemon logs:

```bash
tail -f /var/log/oasys-sqs-receiver/SqsMessageReceiver.log

```
# Don't remove the dummy files in the messages folder,  it stops the cartridge from raising any error if there are no messages. 

# The file CREATE_ORADIR.sql which is part of Release 7.9.0.0 creates an external directory from where messages are loaded into the database.
# A symbolic link can’t be used to point to the messages folder this does not work with oracle external directories.
# Files are loaded as part of a schedule created by the file, EOR_IMPORT_SQS_JOB.sql which is part of release 7.9.0.0
# Files loaded can be checked by running select * from TERMINATION_FILE_LIST; as eor on the database.

# https://dsdmoj.atlassian.net/wiki/spaces/DSTT/pages/6166872865/OASys+Integration+with+Delius+via+SQS+Queue