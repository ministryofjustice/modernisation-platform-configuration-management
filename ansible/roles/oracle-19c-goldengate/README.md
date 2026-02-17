# oracle-goldengate Ansible Role

This role installs and configures Oracle GoldenGate for the Nomis Streams replacement project:

- Audit Data (AUDITDATA.AUDIT_TABLE/AUDIT_COLUMN)
- Audit Reference (AUDITREF.*)
- MIS Staging (BODISTAGING.STG_*)

## Deployment Architecture

The role supports deployment to **two separate GoldenGate hosts**:

1. **Audit Database Host (T1CAUDG)**: Runs AUDITDATA and AUDITREF replication processes
2. **MIS Database Host (T1CMISG)**: Runs MIS replication process

The **source database (T1CNOMG/Nomis)** runs on a separate host and does not require GoldenGate installation.

### Stream-Specific Deployment

The role automatically detects which database is running locally and deploys only the relevant GoldenGate components:
- **Auto-Detection**: The role checks for running Oracle instances (`ora_pmon_*` processes) and matches them against databases defined in `oracle_goldengate_db`
- **Manual Override**: You can manually set `oracle_goldengate_local_db_sid` if needed (e.g., `T1CAUDG` or `T1CMISG`)
- AUDITDATA and AUDITREF processes are deployed only on hosts running the Audit database (T1CAUDG)
- MIS processes are deployed only on hosts running the MIS database (T1CMISG)

**Detection Logic:**
1. Checks for running Oracle instances on the host
2. Compares running instances with configured databases in `oracle_goldengate_db`
3. Sets `oracle_goldengate_local_db_sid` to the matching database
4. Deploys only the relevant GoldenGate components

### Shared Package Code

Note: AUDITREF and MIS processes share the same database package code but differ in:
- Target database and schema
- MIS includes the `MIS_LOAD_ID` column which AUDITREF does not have

## What it does

- Creates GoldenGate directories and manager param files
- **Configures Oracle database parameters (ENABLE_GOLDENGATE_REPLICATION) on source and target databases**
- Deploys Extract and Replicat parameter templates per stream
- Deploys PL/SQL support packages and control tables
- **Configures credential store for secure database authentication**
- **Deploys start/stop control scripts for all Extract and Replicat processes**
- Provides hooks to convert existing Streams scripts (start/stop, setup) into GoldenGate equivalents

## Features

### Database Parameter Configuration
The role automatically configures the required Oracle database parameters for GoldenGate replication:
- Sets `ENABLE_GOLDENGATE_REPLICATION = TRUE` on all databases defined in `oracle_goldengate_db` (no restart required)
- Automatically derives unique database SIDs from the `oracle_goldengate_db` configuration
- Enables minimal supplemental logging
- **Creates GoldenGate administrator user (`ggadmin`) with DBA privileges**
- Retrieves SYS passwords securely from AWS Secrets Manager (`/oracle/database/${ORACLE_SID}/passwords`)
- Verifies parameter configuration after applying changes

The role will configure parameters on all unique TNS aliases found in the `oracle_goldengate_db` structure (T1CNOMG, T1CAUDG, T1CMISG).

### GoldenGate Database Administrator User
The role creates a dedicated database user (`ggadmin` by default) for GoldenGate operations:
- Created in both MIS and Audit databases
- Granted DBA privilege for full GoldenGate functionality
- Password auto-generated and stored in AWS Secrets Manager at `/oracle/database/${ORACLE_SID}/passwords` (as `ggadmin` key)
- Automatically added to GoldenGate credential store with alias `GGADMIN`
- Used for GoldenGate replication processes and administration

### Credential Store
The role automatically configures an Oracle GoldenGate credential store with aliases for each database connection:
- `SOURCE_DB` - Source database connection
- `AUDIT_DB` - Audit database connection
- `AUDITREF_DB` - Audit Reference database connection
- `MIS_DB` - MIS database connection
- `GGADMIN` - GoldenGate administrator user for local database

These aliases can be used in your Extract/Replicat parameter files instead of hardcoded credentials.

### Process Control Scripts
The role deploys individual control scripts for each stream and a master control script:

**Individual Scripts** (located in `$GGHOME/scripts/`):
- `start_extract_auditdata.sh` / `stop_extract_auditdata.sh`
- `start_replicat_auditdata.sh` / `stop_replicat_auditdata.sh`
- `start_extract_auditref.sh` / `stop_extract_auditref.sh`
- `start_replicat_auditref.sh` / `stop_replicat_auditref.sh`
- `start_extract_mis.sh` / `stop_extract_mis.sh`
- `start_replicat_mis.sh` / `stop_replicat_mis.sh`

**Master Control Script** (`$GGHOME/scripts/ogg_control.sh`):
```bash
# Start all processes for all streams
ogg_control.sh start all both

# Stop only the extract for auditdata
ogg_control.sh stop auditdata extract

# Restart replicat for mis
ogg_control.sh restart mis replicat

# Show status of all processes
ogg_control.sh status all
```

## Usage

### Deploying to Audit Database Host

```yaml
- hosts: audit_db_servers
  roles:
    - role: oracle-19c-goldengate
      oracle_goldengate_home: /u01/app/oracle/product/goldengate/19c
      # Local database SID is automatically detected by checking running Oracle instances
      # Manual override: oracle_goldengate_local_db_sid: T1CAUDG
      # Database SIDs are automatically derived from oracle_goldengate_db structure
      # Override TNS aliases if needed for your environment
      oracle_goldengate_db:
        source:
          tns_alias: T1CNOMG
          schema_owner: OMS_OWNER
        audit:
          tns_alias: T1CAUDG
          schema_owner: AUDITDATA
        auditref:
          tns_alias: T1CAUDG
          schema_owner: AUDITREF
        mis:
          tns_alias: T1CMISG
          schema_owner: BODISTAGING
```

### Deploying to MIS Database Host

```yaml
- hosts: mis_db_servers
  roles:
    - role: oracle-19c-goldengate
      oracle_goldengate_home: /u01/app/oracle/product/goldengate/19c
      # Local database SID is automatically detected by checking running Oracle instances
      # Manual override: oracle_goldengate_local_db_sid: T1CMISG
      # Database SIDs are automatically derived from oracle_goldengate_db structure
```

## Ansible Tags

The role supports granular control via tags for different deployment scenarios:

### General Tags
- `goldengate` - All GoldenGate tasks
- `goldengate-install` - Installation and initial setup only
- `goldengate-config` - Configuration tasks only
- `goldengate-processes` - Extract and Replicat process configuration
- `goldengate-scripts` - Control script deployment

### Host-Specific Tags
- `goldengate-audit` - Tasks for Audit database hosts (AUDITDATA + AUDITREF)
- `goldengate-mis` - Tasks for MIS database hosts

### Process-Specific Tags
- `goldengate-capture` - Extract/capture process configuration
- `goldengate-replicat` - Replicat process configuration
- `goldengate-database-config` - Database parameter configuration
- `goldengate-dbuser` - GoldenGate database user creation
- `goldengate-credentials` - Credential store setup
- `goldengate-database-objects` - Database packages and control tables

### Tag Usage Examples

```bash
# Install and configure GoldenGate on Audit database hosts only
ansible-playbook site.yml --tags goldengate-audit

# Install and configure GoldenGate on MIS database hosts only
ansible-playbook site.yml --tags goldengate-mis

# Deploy only the control scripts
ansible-playbook site.yml --tags goldengate-scripts

# Configure only the database parameters
ansible-playbook site.yml --tags goldengate-database-config

# Deploy only replicat processes
ansible-playbook site.yml --tags goldengate-replicat

# Install GoldenGate software only (no configuration)
ansible-playbook site.yml --tags goldengate-install --skip-tags goldengate-config
```

## Prerequisites

- Oracle Database 19c installed and running
- Existing Oracle OS user and group (typically `oracle` and `oinstall`) on the host
- AWS CLI configured on the target host (for retrieving database passwords)
- SYS passwords stored in AWS Secrets Manager at `/oracle/database/${ORACLE_SID}/passwords`
  - Secret should be in JSON format with a `sys` key, e.g., `{"sys": "password123"}`
  - The `ggadmin` password will be added to the same secret as an additional key
- EC2 instance role with permissions to read from Secrets Manager
- EC2 instance role with permissions to update secrets in Secrets Manager (for ggadmin password storage)

## Important Notes

- **OS Users**: The role uses existing Oracle OS user (`oracle_goldengate_owner: oracle`) and group (`oracle_goldengate_group: oinstall`). These must already exist on the host.
- **Database User**: The role creates a DATABASE user named `ggadmin` (configurable via `oracle_goldengate_dbuser`) in the target databases (AUD and MIS) with DBA privileges for GoldenGate operations.