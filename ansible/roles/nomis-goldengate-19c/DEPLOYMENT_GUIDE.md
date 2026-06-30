# GoldenGate Deployment Architecture and Tags Guide

## Deployment Architecture

### Overview
The Oracle GoldenGate 19c installation supports three replication streams. GoldenGate is installed on a **single target host** which runs both the Audit (T1CAUDG) and MIS (T1CMISG) databases. A single playbook run detects all running Oracle instances and deploys all matching stream components automatically.

```
┌─────────────────┐        ┌──────────────────────────────────────┐
│  Source Host    │        │  GoldenGate Target Host              │
│  (Nomis)        │───────>│                                      │
│                 │   │    │  T1CAUDG (Audit DB)                  │
│  T1CNOMG        │   │    │  GoldenGate: AUDITDATA, AUDITREF     │
│  (OMS_OWNER)    │   │    │                                      │
│                 │   │    │  T1CMISG (MIS DB)                    │
│  No GG Install  │   └───>│  GoldenGate: MIS                     │
└─────────────────┘        └──────────────────────────────────────┘
```

### Databases and Their Processes

#### 1. Source Database (Nomis - T1CNOMG)
- **No GoldenGate Installation Required**
- Database parameters configured only (ENABLE_GOLDENGATE_REPLICATION)
- Source for all three replication streams

#### 2. Audit Database (T1CAUDG) — on the GoldenGate target host
**Deploys Two GoldenGate Processes:**
- **AUDITDATA** - Replicates to AUDITDATA.AUDIT_TABLE and AUDIT_COLUMN
  - Extract: EXTAUDD
  - Replicat: REPAUDD
- **AUDITREF** - Replicates all tables from OMS_OWNER to AUDITREF schema
  - Extract: EXTAUDR
  - Replicat: REPAUDR

**Shared Characteristics:**
- AUDITREF shares database package code with MIS process
- Both use T1CAUDG as their target database
- Different schemas (AUDITDATA vs AUDITREF)

#### 3. MIS Database (T1CMISG) — on the GoldenGate target host
**Deploys One GoldenGate Process:**
- **MIS** - Replicates to BODISTAGING.STG_* tables
  - Extract: EXTMIS
  - Replicat: REPMIS

**Key Difference:**
- Uses same package code as AUDITREF but adds MIS_LOAD_ID column
- Separate target database (T1CMISG)

---

## Configuration Variables

### Critical Variable: oracle_goldengate_local_db_sid

This variable is **optional**. By default the role auto-detects all running Oracle instances and deploys components for every matching database in one pass. Set this variable only when you want to restrict a run to a specific database's streams — for example, when applying a targeted update or troubleshooting a single stream.

```yaml
# Default (not set): auto-detects both T1CAUDG and T1CMISG, deploys all streams
# oracle_goldengate_local_db_sid: ""

# Override: restrict to Audit database streams only
oracle_goldengate_local_db_sid: T1CAUDG  # Deploys: AUDITDATA + AUDITREF only

# Override: restrict to MIS stream only
oracle_goldengate_local_db_sid: T1CMISG  # Deploys: MIS only
```

**Auto-Detection Process:**
1. Searches for running Oracle processes: `ps -ef | grep ora_pmon_`
2. Extracts database SIDs from process names
3. Matches against configured databases in `oracle_goldengate_group`
4. Sets `oracle_goldengate_local_db_sid` automatically
5. If multiple matches, uses the first one found

### Auto-Computed Deployment Flags

Based on `oracle_goldengate_local_db_sid`, these flags are automatically set:

```yaml
run_auditdata: true/false
run_auditref: true/false
run_mis: true/false
```

---

## Ansible Tags Reference

### Complete Tag Hierarchy

```
goldengate (ALL TASKS)
├── goldengate-install (Installation & Setup)
│   ├── goldengate-audit (Audit-specific install)
│   ├── goldengate-mis (MIS-specific install)
│   └── goldengate-database-config (DB parameter setup)
│
├── goldengate-config (Configuration Tasks)
│   ├── goldengate-audit (Audit-specific config)
│   ├── goldengate-mis (MIS-specific config)
│   ├── goldengate-credentials (Credential store)
│   ├── goldengate-database-objects (Packages/tables)
│   ├── goldengate-processes (Extract & Replicat)
│   │   ├── goldengate-extract (Extract processes)
│   │   └── goldengate-replicat (Replicat processes)
│   └── goldengate-scripts (Control scripts)
```

### Tag Matrix by Task

| Task | Tags |
|------|------|
| Install GoldenGate | `goldengate`, `goldengate-install`, `goldengate-audit`, `goldengate-mis` |
| Detect Local Database | `goldengate`, `goldengate-install`, `goldengate-config`, `goldengate-audit`, `goldengate-mis` |
| Configure DB Parameters | `goldengate`, `goldengate-install`, `goldengate-database-config`, `goldengate-audit`, `goldengate-mis` |
| Configure GG Home | `goldengate`, `goldengate-install`, `goldengate-config`, `goldengate-audit`, `goldengate-mis` |
| Create GG DB User | `goldengate`, `goldengate-install`, `goldengate-database-config`, `goldengate-dbuser`, `goldengate-audit`, `goldengate-mis` |
| Configure Credentials | `goldengate`, `goldengate-install`, `goldengate-config`, `goldengate-credentials`, `goldengate-audit`, `goldengate-mis` |
| Deploy DB Objects | `goldengate`, `goldengate-config`, `goldengate-database-objects`, `goldengate-audit`, `goldengate-mis` |
| Configure Extract (Audit) | `goldengate`, `goldengate-config`, `goldengate-processes`, `goldengate-audit`, `goldengate-extract` |
| Configure Replicat (Audit) | `goldengate`, `goldengate-config`, `goldengate-processes`, `goldengate-audit`, `goldengate-replicat` |
| Configure Extract (MIS) | `goldengate`, `goldengate-config`, `goldengate-processes`, `goldengate-mis`, `goldengate-extract` |
| Configure Replicat (MIS) | `goldengate`, `goldengate-config`, `goldengate-processes`, `goldengate-mis`, `goldengate-replicat` |
| Deploy Control Scripts | `goldengate`, `goldengate-config`, `goldengate-scripts`, `goldengate-audit`, `goldengate-mis` |

---

## Common Deployment Scenarios

### Scenario 1: Full Deployment to the Target Host

With both databases running, a single run deploys all streams automatically:

```bash
ansible-playbook site.yml \
  --tags goldengate
```

To restrict to one database's streams only:

```bash
# Audit database streams only
ansible-playbook site.yml \
  --tags goldengate-audit \
  --extra-vars "oracle_goldengate_local_db_sid=T1CAUDG"

# MIS stream only
ansible-playbook site.yml \
  --tags goldengate-mis \
  --extra-vars "oracle_goldengate_local_db_sid=T1CMISG"
```

### Scenario 2: Install Software Only (No Configuration)

```bash
ansible-playbook site.yml \
  --tags goldengate-install \
  --skip-tags goldengate-config
```

### Scenario 3: Update Configuration Only (No Reinstall)

```bash
# Updates config for all detected streams
ansible-playbook site.yml \
  --tags goldengate-config \
  --skip-tags goldengate-install
```

### Scenario 4: Deploy Control Scripts Only

```bash
# Update scripts on the GoldenGate target host
ansible-playbook site.yml \
  --tags goldengate-scripts
```

### Scenario 5: Configure Database Parameters Only

```bash
# Configure DB parameters on all database hosts (including source)
ansible-playbook site.yml \
  --tags goldengate-database-config
```

### Scenario 6: Update Extract Processes Only

```bash
# Update Extract processes for all detected streams
ansible-playbook site.yml --tags goldengate-extract

# Or restrict to a specific stream
ansible-playbook site.yml \
  --extra-vars "oracle_goldengate_local_db_sid=T1CAUDG" \
  --tags goldengate-extract,goldengate-audit

ansible-playbook site.yml \
  --extra-vars "oracle_goldengate_local_db_sid=T1CMISG" \
  --tags goldengate-extract,goldengate-mis
```

### Scenario 7: Update Replicat Processes Only

```bash
# Update Replicat processes for all detected streams
ansible-playbook site.yml --tags goldengate-replicat

# Or restrict to Audit database streams
ansible-playbook site.yml \
  --extra-vars "oracle_goldengate_local_db_sid=T1CAUDG" \
  --tags goldengate-replicat,goldengate-audit
```

---

## Inventory Structure

### Example Inventory File

```yaml
---
all:
  children:
    goldengate_hosts:
      hosts:
        goldengate-db-01:
          ansible_host: 10.0.1.10
          ansible_user: ec2-user
          # Both T1CAUDG and T1CMISG run on this host.
          # Always set oracle_goldengate_local_db_sid explicitly via extra-vars
          # when running the playbook to target a specific database stream.

    source_database:
      hosts:
        nomis-db-01:
          ansible_host: 10.0.1.20
          ansible_user: ec2-user
          # No GoldenGate installation
          # Only database parameter configuration if needed
```

---

## Workflow Examples

### Workflow 1: Initial Full Deployment

```yaml
# A single play against the target host — auto-detection deploys all streams
- name: Deploy GoldenGate - all streams
  hosts: goldengate_hosts
  roles:
    - role: oracle-19c-goldengate
  tags: goldengate
```

### Workflow 2: Update Process Configuration Only

```yaml
- name: Update GoldenGate process configuration
  hosts: goldengate_hosts
  roles:
    - role: oracle-19c-goldengate
  tags:
    - goldengate-processes
    - goldengate-scripts
```

### Workflow 3: Emergency Script Deployment

```yaml
- name: Deploy updated control scripts
  hosts: goldengate_hosts
  roles:
    - role: oracle-19c-goldengate
  tags: goldengate-scripts
```

---

## Conditional Deployment Logic

### How Conditional Deployment Works

The role uses these conditions to determine what to deploy:

```yaml
# In tasks/configure_extract.yml
when: run_auditdata
when: run_auditref
when: run_mis

# These are computed from:
run_auditdata: "{{ oracle_goldengate_local_db_sid == 'T1CAUDG' }}"
run_auditref: "{{ oracle_goldengate_local_db_sid == 'T1CAUDG' }}"
run_mis: "{{ oracle_goldengate_local_db_sid == 'T1CMISG' }}"
```

### What Gets Deployed When

| Component | Targeting T1CAUDG | Targeting T1CMISG |
|-----------|-------------------|-------------------|
| GoldenGate Software | ✅ Yes | ✅ Yes |
| Credential Store | ✅ Yes | ✅ Yes |
| Manager Config | ✅ Yes | ✅ Yes |
| AUDITDATA Extract | ✅ Yes | ❌ No |
| AUDITDATA Replicat | ✅ Yes | ❌ No |
| AUDITREF Extract | ✅ Yes | ❌ No |
| AUDITREF Replicat | ✅ Yes | ❌ No |
| MIS Extract | ❌ No | ✅ Yes |
| MIS Replicat | ❌ No | ✅ Yes |
| Control Scripts (all) | ✅ Conditional* | ✅ Conditional* |
| Operations Guide | ✅ Yes | ✅ Yes |

*Control scripts are deployed only for the processes configured on that host

---

## Testing and Validation

### Verify Correct Deployment

**When targeting T1CAUDG:**
```bash
# Should show EXTAUDD, REPAUDD, EXTAUDR, REPAUDR
cd $GGHOME
./ggsci
GGSCI> INFO ALL
```

**When targeting T1CMISG:**
```bash
# Should show EXTMIS, REPMIS only
cd $GGHOME
./ggsci
GGSCI> INFO ALL
```

### Check Deployed Scripts

**After targeting T1CAUDG:**
```bash
ls -la $GGHOME/scripts/
# Should have:
# - start/stop_extract_auditdata.sh
# - start/stop_replicat_auditdata.sh
# - start/stop_extract_auditref.sh
# - start/stop_replicat_auditref.sh
# - ogg_control.sh
```

**After targeting T1CMISG:**
```bash
ls -la $GGHOME/scripts/
# Should have:
# - start/stop_extract_mis.sh
# - start/stop_replicat_mis.sh
# - ogg_control.sh
```

---

## Best Practices

1. **Let auto-detection handle stream selection** — the role detects all running databases and deploys all matching streams in one run; no need to set `oracle_goldengate_local_db_sid` for normal deployments
2. **Use `oracle_goldengate_local_db_sid`** only when you need to restrict a run to a single stream (e.g. targeted updates, troubleshooting)
3. **Use tags** to control which parts of the role execute
4. **Test with `--check` mode** first when possible
5. **Use `--limit`** to target specific hosts during maintenance
6. **Keep database SID lists** consistent across environments via config files

---

## Troubleshooting

### Issue: Wrong processes deployed for a stream

**Cause:** `oracle_goldengate_local_db_sid` is set to the wrong value, overriding auto-detection.

**Solution:** Either clear the override to let auto-detection run all streams, or set the correct SID:
```bash
# Let auto-detection handle it (deploys all running streams)
ansible-playbook site.yml --tags goldengate

# Or explicitly target one stream
ansible-playbook site.yml --extra-vars "oracle_goldengate_local_db_sid=T1CAUDG"
```

### Issue: Auto-detection fails - no database detected

**Cause:** No Oracle database running or database not in `oracle_goldengate_group`

**Solution:**
1. Verify Oracle database is running:
   ```bash
   ps -ef | grep ora_pmon
   ```
2. Check the SID matches one in `oracle_goldengate_group`:
   ```yaml
   oracle_goldengate_group:
     audit:
       tns_alias: T1CAUDG  # Must match running instance
   ```
3. Manually set if auto-detection doesn't work:
   ```yaml
   oracle_goldengate_local_db_sid: T1CAUDG
   ```

### Issue: Auto-detection deploys the wrong stream

**Cause:** `oracle_goldengate_local_db_sid` was set (either in inventory or as an extra-var) and is pointing to the wrong database, overriding auto-detection.

**Solution:** Remove the override to let auto-detection run, or correct the SID value:
```bash
ansible-playbook site.yml --extra-vars "oracle_goldengate_local_db_sid=T1CAUDG"
ansible-playbook site.yml --extra-vars "oracle_goldengate_local_db_sid=T1CMISG"
```

### Issue: Processes not created in GGSCI

**Cause:** Conditional deployment prevented process configuration

**Solution:** Check that local_db_sid matches the expected database

### Issue: Tags not working as expected

**Cause:** Multiple tags may be required for some operations

**Solution:** Check tag matrix above and combine tags appropriately
