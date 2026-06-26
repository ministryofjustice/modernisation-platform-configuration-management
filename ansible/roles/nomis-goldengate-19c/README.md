# nomis-goldengate-19c Ansible Role

This role installs and configures Oracle GoldenGate for the Nomis Oracle Streams replacement project:

- Audit Data (AUDITDATA.AUDIT_TABLE/AUDIT_COLUMN)
- Audit Reference (AUDITREF.*)
- MIS Staging (BODISTAGING.STG_*)

## Deployment Architecture

The role deploys the GoldenGate software to a **single target host** which runs both the Audit (T1CAUDG) and MIS (T1CMISG) databases. A single playbook run will detect all running Oracle instances and deploy the relevant GoldenGate components for each — no separate runs required.

The **source database (T1CNOMG/Nomis)** runs on a separate host and does not require GoldenGate installation.

The databases can be version 11g, 19c or a mixture of versions e.g. 11g for the source and 19c for the target databases.

### Stream-Specific Deployment

The role automatically detects which databases are running locally and deploys all relevant GoldenGate components in one pass:
- **Auto-Detection (default)**: The role checks for running Oracle instances (`ora_pmon_*` processes), matches them against all `tns_alias` values in `oracle_goldengate_group`, and sets deployment flags for every matched database. If both T1CAUDG and T1CMISG are running, all three streams (AUDITDATA, AUDITREF, MIS) are deployed in a single run.
- **Manual Override (optional)**: Set `oracle_goldengate_local_db_sid` to `T1CAUDG` or `T1CMISG` to restrict deployment to a single database's streams — useful for targeted updates or troubleshooting.
- AUDITDATA and AUDITREF components are deployed when the Audit database (T1CAUDG) is detected or targeted
- MIS components are deployed when the MIS database (T1CMISG) is detected or targeted

**Detection Logic:**
1. Checks for running Oracle instances on the host
2. Compares running instances with all configured `tns_alias` values in `oracle_goldengate_group`
3. Sets `run_auditdata`, `run_auditref`, and `run_mis` flags for every matching database
4. Deploys all relevant GoldenGate components in one run

### Shared Package Code

Note: AUDITREF and MIS processes share the same database package code but differ in:
- Target database and schema
- MIS includes the `MIS_LOAD_ID` column which AUDITREF does not have

## What it does

- Creates GoldenGate directories and manager param files
- Configures Oracle database parameters (ENABLE_GOLDENGATE_REPLICATION) on source and target databases
- Deploys Extract and Replicat parameter templates per stream
- Deploys PL/SQL support packages and control tables
- Configures credential store for secure database authentication
- Deploys start/stop control scripts for all Extract and Replicat processes
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
- Configured archive log shipping parameters in the source database to ship logs to the target databases. Parameters log_archive_dest_7 and log_archive_dest_8 are used in the source database.

### GoldenGate Database Users
The role creates a dedicated database user (`ggadmin` by default) for GoldenGate operations:
- Created in all databases
- Granted privileges through dbms_goldengate_auth for GoldenGate functionality
- Password auto-generated and stored in AWS Secrets Manager at `/oracle/database/${ORACLE_SID}/passwords` (as `ggadmin` key)
- Automatically added to GoldenGate credential store with alias `GGADMIN`
- Used for GoldenGate replication processes and administration

For the Auditdata stream the role creates a dummy schema in the target database and creates the table structures based on the source schema. This is required in order to use MAP in the Replicat param file for mapping because replicat expects to be able to query the target database for metadata about the source tables, and if we use TABLEEXCLUDE for all tables then it won't be able to find any metadata and will fail. The dummy tables can be empty because we are not actually replicating any data, we just need them to exist so that the replicat can start successfully and apply the filtering logic in the parameter file.

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

### Deploying to Database Hosts

```yaml
    # Override TNS aliases in the group_vars environment config
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

## Ansible Tags

The role supports granular control via tags for different deployment scenarios:

### General Tags
- `goldengate` - All GoldenGate tasks
- `goldengate-install` - Installation and initial setup only
- `goldengate-config` - Configuration tasks only
- `goldengate-processes` - Extract and Replicat process configuration
- `goldengate-scripts` - Control script deployment

### Host-Specific Tags
- `goldengate-audit` - Tasks for the Audit database (AUDITDATA + AUDITREF)
- `goldengate-mis` - Tasks for the MIS database

### Process-Specific Tags
- `goldengate-extract` - Extract process configuration
- `goldengate-replicat` - Replicat process configuration
- `goldengate-start` - Start all Extract and Replicat processes
- `goldengate-stop` - Stop all Extract and Replicat processes
- `goldengate-start-extract` - Start all Extract processes
- `goldengate-stop-extract` - Stop all Extract processes
- `goldengate-start-replicat` - Start all Replicat processes
- `goldengate-stop-replicat` - Stop all Replicat processes
- `goldengate-database-config` - Database parameter configuration
- `goldengate-dbuser` - GoldenGate database user creation
- `goldengate-credentials` - Credential store setup
- `goldengate-database-objects` - Database packages and control tables

### Scheduler Jobs Migration Tags
- `goldengate-jobs` - All scheduler jobs tasks (includes both tags below)
- `install-migrated-jobs` - Install migrated jobs from STRMADMIN (disabled initially)
- `switchover-jobs` - Switchover from STRMADMIN jobs to migrated jobs

**Note:** Job migration tags include `never` and must be explicitly specified.

See `SCHEDULER_JOBS_MIGRATION.md` for detailed information about the jobs migration process.

### Tag Usage Examples

```bash
# Deploy AUDITDATA and AUDITREF streams (T1CAUDG)
ansible-playbook site.yml --tags goldengate-audit

# Deploy MIS stream (T1CMISG)
ansible-playbook site.yml --tags goldengate-mis

# Deploy only the control scripts
ansible-playbook site.yml --tags goldengate-scripts

# Configure only the database parameters
ansible-playbook site.yml --tags goldengate-database-config

# Deploy only replicat processes
ansible-playbook site.yml --tags goldengate-replicat

# Install GoldenGate software only (no configuration)
ansible-playbook site.yml --tags goldengate-install --skip-tags goldengate-config

# Start all Extract and Replicat processes
ansible-playbook site.yml --tags goldengate-start

# Stop all Audit database processes
ansible-playbook site.yml --tags goldengate-stop,goldengate-audit

# Start only Extract processes
ansible-playbook site.yml --tags goldengate-start-extract

# Stop specific process
ansible-playbook site.yml --tags stop-mis-replicat

# Install migrated scheduler jobs (disabled for testing)
ansible-playbook site.yml --tags install-migrated-jobs

# Switchover from STRMADMIN to migrated jobs
ansible-playbook site.yml --tags switchover-jobs

# Install and switchover jobs for specific database
ansible-playbook site.yml --tags install-migrated-jobs --limit cnom_servers
ansible-playbook site.yml --tags switchover-jobs --limit cnom_servers
```

## Prerequisites

- Oracle Database 11g installed and running
- Existing Oracle OS user and group (typically `oracle` and `oinstall`) on the host
- AWS CLI configured on the target host (for retrieving database passwords)
- SYS passwords stored in AWS Secrets Manager at `/oracle/database/${ORACLE_SID}/passwords`
  - Secret should be in JSON format with a `sys` key, e.g., `{"sys": "password123"}`
  - The `ggadmin` password will be added to the same secret as an additional key
- EC2 instance role with permissions to read from Secrets Manager
- EC2 instance role with permissions to update secrets in Secrets Manager (for ggadmin password storage)

## Important Notes

- **OS Users**: The role uses existing Oracle OS user (`oracle_goldengate_owner: oracle`) and group (`oracle_goldengate_osgroup: oinstall`). These must already exist on the host.
- **Database User**: The role creates a DATABASE user named `ggadmin` (configurable via `oracle_goldengate_dbuser`) in the target databases (AUD and MIS) with DBA privileges for GoldenGate operations.