# Scheduler Jobs Migration Guide

## Overview

This guide describes the migration of Oracle Scheduler jobs from the `STRMADMIN` database account to appropriate schema owners in preparation for upgrading from Oracle Streams to GoldenGate and eventually to Oracle 19c.

## Background

The `STRMADMIN` schema was used with Oracle Streams in Oracle 11g. As we migrate to GoldenGate and prepare for Oracle 19c (where Streams is not supported), all scheduler jobs owned by `STRMADMIN` must be migrated to appropriate schema owners.

**Total Jobs to Migrate: 29 jobs across 3 databases**
- CNOM: 4 jobs (3 migrated, 1 requires manual intervention)
- MIS: 8 jobs (6 migrated, 2 replaced by cron)
- CNMAUD: 17 jobs (13 migrated, 4 not needed)

## Migration Strategy

### Phase 1: Installation (Jobs Disabled)
- Jobs are created in the target schemas but remain **DISABLED**
- This allows testing and validation without affecting production
- Old STRMADMIN jobs continue to run during this phase

### Phase 2: Switchover
- STRMADMIN jobs are **DISABLED**
- Migrated jobs are **ENABLED**
- This is a controlled cutover point

## Jobs by Database

### CNOM Database (4 jobs total + 1 new)

| Original Job Name | New Owner | New Job Name | Status | Enabled After Switchover? |
|------------------|-----------|--------------|--------|---------------------------|
| BATCH_STATUS_EXTRACT_JOB | OMS_OWNER | BATCH_STATUS_EXTRACT_JOB | Migrated | NO (last run 2018) |
| MIS_BATCH_CONTROL_CHAIN_JOB | - | - | Not Migrated | Manual migration required |
| ORCL_BATCH_STATUS_EXTRACT_JOB | OMS_OWNER | ORCL_BATCH_STATUS_EXTRACT_JOB | Migrated | NO (last run 2018) |
| WEEKLY_DD_DUMP | SYS | CNOM_WEEKLY_DD_DUMP | Migrated | NO (never run, not needed) |
| **N/A (New Job)** | **SYS** | **BUILD_LOGMINER_DICT_HOURLY** | **New** | **YES** |

**Summary:** 3 jobs migrated (all disabled), 1 new job created (enabled), 1 requires manual migration

### MIS Database (8 jobs total)

| Original Job Name | New Owner | New Job Name | Status | Enabled After Switchover? |
|------------------|-----------|--------------|--------|---------------------------|
| DAILY_LOG_PURGE | - | - | Not Migrated | Already in root crontab |
| MISLOAD_FAILURE_CHECK | - | - | Not Migrated | Should be cron job |
| MIS_BATCH_CONTROL | BODISTAGING | MIS_BATCH_CONTROL | Migrated | NO (disabled) |
| MIS_BATCH_ROLL | BODISTAGING | MIS_BATCH_ROLL | Migrated | NO (disabled) |
| MIS_PRE_LOAD | BODISTAGING | MIS_PRE_LOAD | Migrated | NO (disabled) |
| MIS_PURGE_STAGING_TABLES | BODISTAGING | MIS_PURGE_STAGING_TABLES | Migrated | YES |
| ORCL_BATCH_STATUS_EXTRACT_JOB | BODISTAGING | ORCL_BATCH_STATUS_EXTRACT_JOB | Migrated | NO (last run 2018) |
| WEEKLY_LOG_PURGE | BODISTAGING | WEEKLY_LOG_PURGE | Migrated | YES (PPMIS only) |

**Summary:** 6 jobs migrated (2 enabled), 2 not migrated (use cron)

### CNMAUD Database (17 jobs total)

| Original Job Name | New Owner | New Job Name | Status | Enabled After Switchover? |
|------------------|-----------|--------------|--------|---------------------------|
| ADD_WKLY_DATA_PARTS | AUDITDATA | ADD_WKLY_DATA_PARTS | Migrated | YES |
| ARCH_WKLY_DATA_PARTS | AUDITDATA | ARCH_WKLY_DATA_PARTS | Migrated | YES |
| AUDIT DEQUEUE | - | - | Not Migrated | Procedure no longer exists |
| AUDIT_DATA_PURGE | AUDITDATA | AUDIT_DATA_PURGE | Migrated | YES |
| AUDIT_DATA_UPLOAD_TO_S3 | SYS | AUDIT_DATA_UPLOAD_TO_S3 | Migrated | YES (PDCNMAUD only) |
| AUDIT_LOG_IMPORT_CHAIN_JOB | - | - | Not Migrated | Last run 2018 |
| AUDIT_REFERENCE | - | - | Not Migrated | Duplicate of #14 |
| BKUP_WKLY_RO_TABLESPACES | - | - | Not Migrated | SBT tablespace doesn't exist |
| DAILY_LOG_PURGE | - | - | Not Migrated | Already in root crontab |
| GATHER_STATS_AUDITDATA_TABS | AUDITDATA | GATHER_STATS_AUDITDATA_TABS | Migrated | YES |
| GATHER_STATS_AUDITREF_TABS | AUDITREF | GATHER_STATS_AUDITREF_TABS | Migrated | YES |
| GATHER_STATS_AUDIT_COLUMN | AUDITDATA | GATHER_STATS_AUDIT_COLUMN | Migrated | YES |
| GATHER_STATS_AUDIT_TABLE | AUDITDATA | GATHER_STATS_AUDIT_TABLE | Migrated | YES |
| OFFENDER_CROSS_REFERENCE_UPD | AUDITDATA | OFFENDER_CROSS_REFERENCE_UPD | Migrated | YES |
| ORCL_BATCH_STATUS_EXTRACT_JOB | AUDITDATA | ORCL_BATCH_STATUS_EXTRACT_JOB | Migrated | NO (last run 2018) |
| REMOTE_AUDIT_IMPORT | AUDITDATA | REMOTE_AUDIT_IMPORT | Migrated | NO (last run Mar 2023) |
| WEEKLY_LOG_PURGE | SYS | AUDIT_WEEKLY_LOG_PURGE | Migrated | NO (ineffective) |

**Summary:** 13 jobs migrated (10 enabled), 4 not migrated

## Usage

### Phase 1: Install Jobs (Disabled)

Run the installation playbook with the appropriate tags:

```bash
# Install jobs for all databases
ansible-playbook site.yml --tags install-migrated-jobs

# Or for specific databases
ansible-playbook site.yml --tags install-migrated-jobs --limit cnom_servers
ansible-playbook site.yml --tags install-migrated-jobs --limit mis_servers
ansible-playbook site.yml --tags install-migrated-jobs --limit audit_servers
```

After installation, verify jobs are created but disabled:

```sql
-- Check CNOM jobs
SELECT owner, job_name, enabled, state 
FROM dba_scheduler_jobs 
WHERE owner IN ('OMS_OWNER', 'SYS') 
  AND (owner != 'SYS' OR job_name LIKE 'CNOM_%')
ORDER BY owner, job_name;

-- Check MIS jobs
SELECT owner, job_name, enabled, state 
FROM dba_scheduler_jobs 
WHERE owner IN ('BODISTAGING')
ORDER BY owner, job_name;

-- Check AUDIT jobs
SELECT owner, job_name, enabled, state 
FROM dba_scheduler_jobs 
WHERE owner IN ('AUDITDATA', 'AUDITREF', 'SYS')
  AND (owner NOT IN ('SYS') OR job_name LIKE 'AUDIT_%')
ORDER BY owner, job_name;
```

### Phase 2: Switchover

When ready to switch from STRMADMIN jobs to migrated jobs:

```bash
# Switchover all databases
ansible-playbook site.yml --tags switchover-jobs

# Or for specific databases
ansible-playbook site.yml --tags switchover-jobs --limit cnom_servers
ansible-playbook site.yml --tags switchover-jobs --limit mis_servers
ansible-playbook site.yml --tags switchover-jobs --limit audit_servers
```

The switchover script will:
1. Disable all STRMADMIN jobs
2. Enable the migrated jobs (except those marked to remain disabled)
3. Display the current status of all jobs

### Manual Switchover (if needed)

You can also run the switchover scripts manually:

```bash
# On CNOM database
cd /home/oracle/admin/goldengate/sql/source
sqlplus / as sysdba @switchover_source_jobs.sql

# On MIS database
cd /home/oracle/admin/goldengate/sql/mis
sqlplus / as sysdba @switchover_mis_jobs.sql

# On AUDIT database
cd /home/oracle/admin/goldengate/sql/auditdata
sqlplus / as sysdba @switchover_audit_jobs.sql
```

## Validation

After switchover, monitor the migrated jobs:

```sql
-- Check job execution history
SELECT 
    owner,
    job_name,
    log_date,
    status,
    error#,
    additional_info
FROM dba_scheduler_job_run_details
WHERE owner IN ('OMS_OWNER', 'BODISTAGING', 'AUDITDATA', 'AUDITREF')
ORDER BY log_date DESC;

-- Check currently running jobs
SELECT 
    owner,
    job_name,
    state,
    running_instance,
    elapsed_time
FROM dba_scheduler_running_jobs
WHERE owner IN ('OMS_OWNER', 'BODISTAGING', 'AUDITDATA', 'AUDITREF');
```

## Rollback

If you need to rollback to STRMADMIN jobs:

```sql
-- Re-enable STRMADMIN jobs
BEGIN
    FOR rec IN (SELECT job_name FROM dba_scheduler_jobs WHERE owner = 'STRMADMIN') LOOP
        DBMS_SCHEDULER.ENABLE(name => 'STRMADMIN.' || rec.job_name);
        DBMS_OUTPUT.PUT_LINE('Enabled: STRMADMIN.' || rec.job_name);
    END LOOP;
END;
/

-- Disable migrated jobs
BEGIN
    FOR rec IN (SELECT owner, job_name 
                FROM dba_scheduler_jobs 
                WHERE owner IN ('OMS_OWNER', 'BODISTAGING', 'AUDITDATA', 'AUDITREF')
                AND enabled = 'TRUE') LOOP
        DBMS_SCHEDULER.DISABLE(name => rec.owner || '.' || rec.job_name, force => TRUE);
        DBMS_OUTPUT.PUT_LINE('Disabled: ' || rec.owner || '.' || rec.job_name);
    END LOOP;
END;
/
```

## Notes

### Jobs Left Disabled After Switchover

The following jobs are intentionally left disabled after switchover:

1. **BATCH_STATUS_EXTRACT** (CNOM, MIS, AUDIT) - Last run in 2018, output directory doesn't exist
2. **PURGE_STAGING_TABLES** (CNOM, MIS) - Last run in 2018, may not be needed
3. **REMOTE_AUDIT_IMPORT** (AUDIT) - Last run March 2023, no longer in use
4. **WEEKLY_LOG_PURGE jobs owned by SYS** - Replaced by cron jobs or ineffective

These can be manually enabled if needed, but should be validated first.

### Package Dependencies

The migrated jobs use the following packages:

- **CNOM**: `CNOM_JOB_PKG`, `CNOM_BATCH_PKG` (to be created)
- **MIS**: `MIS_JOB_PKG`, `MIS_BATCH_PKG`
- **AUDIT**: `AUDITDATA_JOB_PKG`, `AUDITREF_JOB_PKG` (to be created)

Ensure these packages are installed before running the job installation scripts.

## Files Created

### SQL Templates
- `templates/sql/source/install_source_jobs.sql.j2` - Create CNOM jobs
- `templates/sql/source/switchover_source_jobs.sql.j2` - Switchover CNOM jobs
- `templates/sql/mis/install_mis_jobs.sql.j2` - Create MIS jobs (updated)
- `templates/sql/mis/switchover_mis_jobs.sql.j2` - Switchover MIS jobs
- `templates/sql/auditdata/install_audit_jobs.sql.j2` - Create AUDIT jobs
- `templates/sql/auditdata/switchover_audit_jobs.sql.j2` - Switchover AUDIT jobs

### Ansible Tasks
- `tasks/install_migrated_jobs.yml` - Install jobs across all databases
- `tasks/switchover_jobs.yml` - Switchover jobs across all databases

### Updated Files
- `tasks/main.yml` - Added new task imports with tags
- `templates/sql/auditdata/AUDITDATA_JOB_PKG.sql.j2` - Added stats gathering procedure
- `templates/sql/auditdata/AUDITDATA_JOB_PBODY.sql.j2` - Implemented stats gathering procedure

## Support

For questions or issues with the job migration, refer to:
- Excel file: `nomis-jobs.xlsx` - Original job analysis with migration decisions
- This guide: `SCHEDULER_JOBS_MIGRATION.md`
- Role README: `README.md`
