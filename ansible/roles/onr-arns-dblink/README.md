# onr-arns-dblink

Configures Oracle Heterogeneous Services (HS) and ODBC connectivity so an Oracle database can access the ARNS PostgreSQL RDS database in Cloud Platform via a database link (`PG`).

## What this role does

1. Validates required inputs and platform support.
2. Installs PostgreSQL ODBC components:
   - EL7: installs staged RPMs from S3.
   - EL8/EL9: installs repository packages.
3. Retrieves PostgreSQL connection details from AWS Secrets Manager.
4. Creates `/etc/odbc.ini` with DSN `[PG]`.
5. Configures Oracle HS gateway init file (`initPG.ora`).
6. Updates Oracle Net config (`tnsnames.ora`) for `PG`.
7. Configures Oracle listener gateway `SID_DESC` for `dg4odbc`.
8. Creates a public Oracle DB link `PG`.
9. Runs optional connectivity validation (`isql` + Oracle probe over `@PG`).

## Requirements

- Ansible collections:
  - `amazon.aws`
- Oracle Database Gateway for ODBC installed (`dg4odbc` present).
- AWS CLI available on target host.
- Target host can access:
  - S3 path for EL7 RPMs (if EL7),
  - Secrets Manager secret,
  - KMS key used to encrypt the secret,
  - PostgreSQL RDS endpoint.
- Oracle environment variables and binaries available via `onr_arns_oracle_home`.

## Role variables

### Required / environment-specific

| Variable | Description | Example |
|---|---|---|
| `onr_arns_secret_id` | Secret id/arn to read from Secrets Manager. | `"/postgres/database/hmpps-arns-assessment-view-db-preprod/cloud-platform-config"` |
| `onr_arns_oracle_home` | Oracle home containing `sqlplus` and `dg4odbc`. | `"/u01/app/oracle/product/19c/db_1"` |
| `s3_bucket` | Bucket containing staged EL7 ODBC RPMs. | `"modernisation-platform-amis"` |

> `onr_arns_secret_name` can be derived from environment naming. If your estate uses `preproduction/production` but secret suffixes are `preprod/prod`, ensure your environment mapping logic normalizes this.

### Commonly used defaults

| Variable | Default |
|---|---|
| `onr_arns_aws_region` | `eu-west-2` |
| `onr_arns_odbc_ini` | `/etc/odbc.ini` |
| `onr_arns_odbc_dsn` | `PG` |
| `onr_arns_tns_alias` | `PG` |
| `onr_arns_oracle_hs_sid` | `PG` |
| `onr_arns_dblink_name` | `PG` |
| `onr_arns_dblink_type` | `private` |
| `onr_arns_listener_host` | `localhost` |
| `onr_arns_listener_port` | `1521` |
| `onr_arns_validate_isql` | `true` |
| `onr_arns_validate_oracle_query` | `true` |
| `onr_arns_validate_oracle_probe_sql` | `select 1 from dual` |

### Secret JSON keys expected (from AWS Secrets Manager)

The secret `SecretString` is expected to contain:

```json
{
  "username": "...",
  "password": "...",
  "endpoint": "...",
  "port": 5432,
  "db_name": "..."
}
```

Mapped by:

- `onr_arns_secret_username_key` (default `username`)
- `onr_arns_secret_password_key` (default `password`)
- `onr_arns_secret_host_key` (default `endpoint`)
- `onr_arns_secret_port_key` (default `port`)
- `onr_arns_secret_database_key` (default `db_name`)

## Example usage

```yaml
- hosts: onr_db
  become: true
  roles:
    - role: onr-arns-dblink
      vars:
        onr_arns_secret_id: "/postgres/database/hmpps-arns-assessment-view-db-preprod/cloud-platform-config"
        onr_arns_oracle_home: "/u01/app/oracle/product/11.2.0.4/db_1"
        onr_arns_dblink_type: public
```

## Post-run checks

On target host:

```bash
isql PG <username> <password>
```

In Oracle:

```sql
select count("1") from "assessment-view"."sentence_plan"@PG;
```

## Troubleshooting

### `AccessDeniedException: Access to KMS is not allowed`

`GetSecretValue` can fail even with Secrets Manager IAM access if KMS decrypt permission is missing.  
Grant the EC2 instance role `kms:Decrypt` on the KMS key encrypting the secret (key policy or grant).

### EL7 yum mirror DNS warnings during local RPM install

If install succeeds (`rc=0`) from staged RPMs, mirror warnings are usually non-fatal repo refresh noise.  
Optionally disable repos for that task to reduce noise.

## Notes

- The role uses the `PG` naming convention to match deployed behavior.
- Keep credentials out of logs and avoid passing passwords in process args where possible.
```