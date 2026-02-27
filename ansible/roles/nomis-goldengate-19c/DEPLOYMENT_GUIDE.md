# GoldenGate Deployment Architecture and Tags Guide

## Deployment Architecture

### Overview
The Oracle GoldenGate 19c installation supports three replication streams across **two GoldenGate hosts**:

```
┌─────────────────┐        ┌──────────────────┐        ┌─────────────────┐
│  Source Host    │        │ Audit DB Host    │        │  MIS DB Host    │
│  (Nomis)        │───────>│  (T1CAUDG)       │        │  (T1CMISG)      │
│                 │   │    │                  │        │                 │
│  T1CNOMG        │   │    │  GoldenGate:     │        │  GoldenGate:    │
│  (OMS_OWNER)    │   │    │  - AUDITDATA     │        │  - MIS          │
│                 │   │    │  - AUDITREF      │        │                 │
│  NO GG INSTALL  │   └───>│                  │        │                 │
└─────────────────┘         └──────────────────┘        └─────────────────┘
```

### Hosts and Their Processes

#### 1. Source Database Host (Nomis - T1CNOMG)
- **No GoldenGate Installation Required**
- Database parameters configured only (ENABLE_GOLDENGATE_REPLICATION)
- Source for all three replication streams

#### 2. Audit Database Host (T1CAUDG)
**Deploys Two GoldenGate Processes:**
- **AUDITDATA** - Replicates AUDITDATA.AUDIT_TABLE and AUDIT_COLUMN
  - Extract: EXTAUDD
  - Replicat: REPAUDD
- **AUDITREF** - Replicates all tables from OMS_OWNER to AUDITREF schema
  - Extract: EXTAUDR
  - Replicat: REPAUDR

**Shared Characteristics:**
- Both processes share database package code
- Use same target database (T1CAUDG)
- Different schemas (AUDITDATA vs AUDITREF)

#### 3. MIS Database Host (T1CMISG)
**Deploys One GoldenGate Process:**
- **MIS** - Replicates BODISTAGING.STG_* tables
  - Extract: EXTMIS
  - Replicat: REPMIS

**Key Difference:**
- Uses same package code as AUDITREF but adds MIS_LOAD_ID column
- Separate target database (T1CMISG)

---

## Configuration Variables

### Critical Variable: oracle_goldengate_local_db_sid

This variable controls which processes are deployed on each host:

```yaml
# Auto-detected by checking running Oracle instances
# The role will detect which database (T1CAUDG or T1CMISG) is running

# Manual override (if needed):
oracle_goldengate_local_db_sid: T1CAUDG  # Deploys: AUDITDATA + AUDITREF
oracle_goldengate_local_db_sid: T1CMISG  # Deploys: MIS only
```

**Auto-Detection Process:**
1. Searches for running Oracle processes: `ps -ef | grep ora_pmon_`
2. Extracts database SIDs from process names
3. Matches against configured databases in `oracle_goldengate_db`
4. Sets `oracle_goldengate_local_db_sid` automatically
5. If multiple matches, uses the first one found

### Auto-Computed Deployment Flags

Based on `oracle_goldengate_local_db_sid`, these flags are automatically set:

```yaml
oracle_goldengate_deploy_auditdata: true/false
oracle_goldengate_deploy_auditref: true/false
oracle_goldengate_deploy_mis: true/false
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

### Scenario 1: Full Deployment to Both Hosts

**Audit Database Host:**
```bash
ansible-playbook site.yml \
  --limit audit_db_hosts \
  --tags goldengate-audit \
  --extra-vars "oracle_goldengate_local_db_sid=T1CAUDG"
```

**MIS Database Host:**
```bash
ansible-playbook site.yml \
  --limit mis_db_hosts \
  --tags goldengate-mis \
  --extra-vars "oracle_goldengate_local_db_sid=T1CMISG"
```

### Scenario 2: Install Software Only (No Configuration)

```bash
# Install on both hosts
ansible-playbook site.yml \
  --tags goldengate-install \
  --skip-tags goldengate-config
```

### Scenario 3: Update Configuration Only (No Reinstall)

```bash
# Update config on Audit host
ansible-playbook site.yml \
  --limit audit_db_hosts \
  --tags goldengate-config \
  --skip-tags goldengate-install
```

### Scenario 4: Deploy Control Scripts Only

```bash
# Update scripts on all GoldenGate hosts
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
# Update Extract processes on Audit host
ansible-playbook site.yml \
  --limit audit_db_hosts \
  --tags goldengate-extract,goldengate-audit

# Update Extract processes on MIS host
ansible-playbook site.yml \
  --limit mis_db_hosts \
  --tags goldengate-extract,goldengate-mis
```

### Scenario 7: Update Replicat Processes Only

```bash
# Update Replicat processes on Audit host
ansible-playbook site.yml \
  --limit audit_db_hosts \
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
      children:
        audit_goldengate:
          hosts:
            audit-db-01:
              # oracle_goldengate_local_db_sid auto-detected from running instances
              # Database SIDs automatically derived from oracle_goldengate_db
        
        mis_goldengate:
          hosts:
            mis-db-01:
              # oracle_goldengate_local_db_sid auto-detected from running instances
              # Database SIDs automatically derived from oracle_goldengate_db
    
    source_database:
      hosts:
        nomis-db-01:
          # No GoldenGate installation
          # Only database parameter configuration if needed
```

---

## Workflow Examples

### Workflow 1: Initial Full Deployment

```yaml
# Step 1: Configure source database (optional - will be done automatically when deploying to GG hosts)
# Database parameters are automatically configured based on oracle_goldengate_db structure

# Step 2: Deploy to Audit host
- name: Deploy GoldenGate to Audit database
  hosts: audit_goldengate
  roles:
    - role: oracle-19c-goldengate
  tags: goldengate-audit

# Step 3: Deploy to MIS host
- name: Deploy GoldenGate to MIS database
  hosts: mis_goldengate
  roles:
    - role: oracle-19c-goldengate
  tags: goldengate-mis
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
when: oracle_goldengate_deploy_auditdata
when: oracle_goldengate_deploy_auditref
when: oracle_goldengate_deploy_mis

# These are computed from:
oracle_goldengate_deploy_auditdata: "{{ oracle_goldengate_local_db_sid == 'T1CAUDG' }}"
oracle_goldengate_deploy_auditref: "{{ oracle_goldengate_local_db_sid == 'T1CAUDG' }}"
oracle_goldengate_deploy_mis: "{{ oracle_goldengate_local_db_sid == 'T1CMISG' }}"
```

### What Gets Deployed Where

| Component | Audit Host (T1CAUDG) | MIS Host (T1CMISG) |
|-----------|---------------------|-------------------|
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

**On Audit Host:**
```bash
# Should show EXTAUDD, REPAUDD, EXTAUDR, REPAUDR
cd $GGHOME
./ggsci
GGSCI> INFO ALL
```

**On MIS Host:**
```bash
# Should show EXTMIS, REPMIS only
cd $GGHOME
./ggsci
GGSCI> INFO ALL
```

### Check Deployed Scripts

**On Audit Host:**
```bash
ls -la $GGHOME/scripts/
# Should have:
# - start/stop_extract_auditdata.sh
# - start/stop_replicat_auditdata.sh
# - start/stop_extract_auditref.sh
# - start/stop_replicat_auditref.sh
# - ogg_control.sh
```

**On MIS Host:**
```bash
ls -la $GGHOME/scripts/
# Should have:
# - start/stop_extract_mis.sh
# - start/stop_replicat_mis.sh
# - ogg_control.sh
```

---

## Best Practices

1. **Always set `oracle_goldengate_local_db_sid`** in inventory or extra-vars
2. **Use host groups** (audit_goldengate, mis_goldengate) for targeted deployment
3. **Use tags** to control which parts of the role execute
4. **Test with `--check` mode** first when possible
5. **Deploy to one host** at a time initially to validate configuration
6. **Use `--limit`** to target specific hosts during maintenance
7. **Keep database SID lists** consistent across environments via config files

---

## Troubleshooting

### Issue: Wrong processes deployed to a host

**Cause:** `oracle_goldengate_local_db_sid` not set or incorrectly detected

**Solution:**
```yaml
# Check what was detected:
ansible-playbook site.yml --tags goldengate -v | grep "Local database SID"

# Manually override if needed:
oracle_goldengate_local_db_sid: T1CAUDG  # or T1CMISG
```

### Issue: Auto-detection fails - no database detected

**Cause:** No Oracle database running or database not in `oracle_goldengate_db`

**Solution:**
1. Verify Oracle database is running:
   ```bash
   ps -ef | grep ora_pmon
   ```
2. Check the SID matches one in `oracle_goldengate_db`:
   ```yaml
   oracle_goldengate_db:
     audit:
       tns_alias: T1CAUDG  # Must match running instance
   ```
3. Manually set if auto-detection doesn't work:
   ```yaml
   oracle_goldengate_local_db_sid: T1CAUDG
   ```

### Issue: Multiple databases detected on same host

**Cause:** Host runs multiple Oracle instances

**Solution:**
The role will use the first matching instance found. To control which one:
```yaml
# Explicitly set which database to use
oracle_goldengate_local_db_sid: T1CAUDG
```

### Issue: Processes not created in GGSCI

**Cause:** Conditional deployment prevented process configuration

**Solution:** Check that local_db_sid matches the expected database

### Issue: Tags not working as expected

**Cause:** Multiple tags may be required for some operations

**Solution:** Check tag matrix above and combine tags appropriately
