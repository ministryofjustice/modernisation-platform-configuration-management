# Overview

Use this role to install and configure the OASys SQS Message Receiver on an OASys database server.

The role:

- Installs Amazon Corretto 8
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
- The Amazon Corretto repository is configured on the server
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
oasys_sqs_secret_path: "/delius_oasys/dev/queue"
oasys_sqs_poll_interval_seconds: 300
```

# Deployment

Deploy the OASys SQS Message Receiver:

```bash
no_proxy="*" ansible-playbook site.yml --limit t1-oasys-db-a -e force_role=oasys-sqs-receiver
```

# Updating to a New Release

Upload the new release zip to S3 and update:

```yaml
oasys_sqs_release_version: "7.9.1.1"
```

Re-run the role. The existing service will be stopped, the new release deployed and the daemon restarted automatically.

# Service Management

The daemon is installed as a systemd service:

```bash
systemctl status oasys-sqs-receiver
systemctl restart oasys-sqs-receiver
```

Application logs are written to:

```text
/var/log/oasys-sqs-receiver/SqsMessageReceiver.log
```

# Troubleshooting

Verify the daemon is running:

```bash
systemctl status oasys-sqs-receiver
```

Verify Java installation:

```bash
/usr/lib/jvm/java-1.8.0-amazon-corretto/bin/java -version
```

Review daemon logs:

```bash
tail -f /var/log/oasys-sqs-receiver/SqsMessageReceiver.log
```