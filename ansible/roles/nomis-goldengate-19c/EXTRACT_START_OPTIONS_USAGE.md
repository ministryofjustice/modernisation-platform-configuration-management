# GoldenGate Extract Start Options - Usage Guide

## Overview

This guide explains how to control when GoldenGate Extract processes begin processing redo logs. You can start from the current point (default), or from a specific point in time using CSN, SCN, or timestamp.

## Extract Start Options

### 1. BEGIN NOW (Default)
Start processing from the current point in redo logs.

```bash
# Default - no extra variables needed
ansible-playbook site.yml --tags install-audit-extract
```

**When to use:**
- Fresh installation
- Starting replication for the first time
- Don't need historical data

### 2. BEGIN CSN (Commit Sequence Number)
Start processing from a specific commit sequence number.

```bash
ansible-playbook site.yml --tags install-audit-extract \
  --extra-vars "oracle_goldengate_extract_start_mode=csn \
                oracle_goldengate_extract_start_csn=123456789"
```

**When to use:**
- Point-in-time recovery
- Restarting after extract rebuild
- Need to replay specific transactions

### 3. BEGIN SCN (System Change Number)
Start processing from a specific system change number.

```bash
ansible-playbook site.yml --tags install-audit-extract \
  --extra-vars "oracle_goldengate_extract_start_mode=scn \
                oracle_goldengate_extract_start_scn=987654321"
```

**When to use:**
- Coordinating with database flashback
- Matching a specific database backup SCN
- More common than CSN for Oracle operations

### 4. BEGIN TIME (Timestamp)
Start processing from a specific timestamp.

```bash
ansible-playbook site.yml --tags install-audit-extract \
  --extra-vars "oracle_goldengate_extract_start_mode=time \
                oracle_goldengate_extract_start_time='2026-02-27 10:00:00'"
```

**When to use:**
- Know the approximate time but not SCN
- Human-readable recovery point
- Time-based recovery scenarios

## REGISTER EXTRACT with SCN

When registering an integrated extract, you can optionally specify an SCN where the LogMiner session will begin.

```bash
ansible-playbook site.yml --tags install-audit-extract \
  --extra-vars "oracle_goldengate_register_start_mode=scn \
                oracle_goldengate_register_start_scn=123456789"
```

**Important:** When using REGISTER with SCN, you typically want to use the same SCN for ADD EXTRACT:

```bash
ansible-playbook site.yml --tags install-audit-extract \
  --extra-vars "oracle_goldengate_register_start_mode=scn \
                oracle_goldengate_register_start_scn=123456789 \
                oracle_goldengate_extract_start_mode=scn \
                oracle_goldengate_extract_start_scn=123456789"
```

## Getting Current SCN

Before using SCN-based start options, you may want to know the current SCN:

```bash
ansible-playbook site.yml --tags get-current-scn
```

**Output:**
```
Source Database (T1CNOM) Current SCN: 123456789
Local Database (T1CAUDG) Current SCN: 123456790
```

**Use the source database SCN** when registering extracts, as that's where the extract will read from.

## Common Scenarios

### Scenario 1: Fresh Installation
```bash
# Default - uses BEGIN NOW
ansible-playbook site.yml --tags goldengate-install
```

### Scenario 2: Rebuild Extract from Current SCN
```bash
# Step 1: Get current SCN
ansible-playbook site.yml --tags get-current-scn
# Note the SCN: 123456789

# Step 2: Stop and remove old extract (if exists)
# Manual: ggsci> STOP EXTRACT AUDDTEXT
# Manual: ggsci> DELETE EXTRACT AUDDTEXT

# Step 3: Re-register and add with SCN
ansible-playbook site.yml --tags install-audit-extract \
  --extra-vars "oracle_goldengate_register_start_mode=scn \
                oracle_goldengate_register_start_scn=123456789 \
                oracle_goldengate_extract_start_mode=scn \
                oracle_goldengate_extract_start_scn=123456789"

# Step 4: Start extract
ansible-playbook site.yml --tags goldengate-start
```

### Scenario 3: Rebuild Extract from Specific Point in Time
```bash
# Use timestamp instead of SCN
ansible-playbook site.yml --tags install-audit-extract \
  --extra-vars "oracle_goldengate_extract_start_mode=time \
                oracle_goldengate_extract_start_time='2026-02-27 08:00:00'"
```

### Scenario 4: Match Database Backup SCN
```bash
# Get SCN from backup metadata
# Example: RMAN> LIST BACKUP SUMMARY;
# Backup SCN: 987654321

# Register and add extract from backup SCN
ansible-playbook site.yml --tags install-audit-extract \
  --extra-vars "oracle_goldengate_register_start_mode=scn \
                oracle_goldengate_register_start_scn=987654321 \
                oracle_goldengate_extract_start_mode=scn \
                oracle_goldengate_extract_start_scn=987654321"
```

### Scenario 5: Different Start Points per Extract
```bash
# Start AUDITDATA from specific SCN
ansible-playbook site.yml --tags install-audit-extract \
  --extra-vars "oracle_goldengate_deploy_auditdata=true \
                oracle_goldengate_deploy_auditref=false \
                oracle_goldengate_extract_start_mode=scn \
                oracle_goldengate_extract_start_scn=111111111"

# Start AUDITREF from different SCN
ansible-playbook site.yml --tags install-audit-extract \
  --extra-vars "oracle_goldengate_deploy_auditdata=false \
                oracle_goldengate_deploy_auditref=true \
                oracle_goldengate_extract_start_mode=scn \
                oracle_goldengate_extract_start_scn=222222222"

# Start MIS from NOW
ansible-playbook site.yml --tags install-mis-extract
```

## Variables Reference

### Extract Start Variables (defaults/main.yml)

```yaml
# ADD EXTRACT BEGIN clause control
oracle_goldengate_extract_start_mode: "now"
  # Options: now, csn, scn, time
  # Default: now

oracle_goldengate_extract_start_csn: ""
  # CSN number (when mode=csn)
  # Example: "123456789"

oracle_goldengate_extract_start_scn: ""
  # SCN number (when mode=scn)
  # Example: "987654321"

oracle_goldengate_extract_start_time: ""
  # Timestamp (when mode=time)
  # Format: 'YYYY-MM-DD HH24:MI:SS'
  # Example: "2026-02-27 10:00:00"

# REGISTER EXTRACT SCN clause control
oracle_goldengate_register_start_mode: "current"
  # Options: current, scn
  # Default: current (no SCN)

oracle_goldengate_register_start_scn: ""
  # SCN number for REGISTER (when mode=scn)
  # Example: "123456789"
```

## GGSCI Commands Generated

### Default (BEGIN NOW)
```sql
REGISTER EXTRACT AUDDTEXT DATABASE
ADD EXTRACT AUDDTEXT, INTEGRATED TRANLOG, BEGIN NOW
```

### With SCN
```sql
REGISTER EXTRACT AUDDTEXT DATABASE SCN 123456789
ADD EXTRACT AUDDTEXT, INTEGRATED TRANLOG, BEGIN SCN 123456789
```

### With CSN
```sql
REGISTER EXTRACT AUDDTEXT DATABASE
ADD EXTRACT AUDDTEXT, INTEGRATED TRANLOG, BEGIN CSN 123456789
```

### With Timestamp
```sql
REGISTER EXTRACT AUDDTEXT DATABASE
ADD EXTRACT AUDDTEXT, INTEGRATED TRANLOG, BEGIN TIME '2026-02-27 10:00:00'
```

## Troubleshooting

### How to find the right SCN?

**From database:**
```sql
-- Current SCN
SELECT CURRENT_SCN FROM V$DATABASE;

-- SCN at specific time
SELECT TIMESTAMP_TO_SCN(TIMESTAMP '2026-02-27 10:00:00') FROM DUAL;

-- Time from SCN
SELECT SCN_TO_TIMESTAMP(123456789) FROM DUAL;
```

**From RMAN backup:**
```sql
RMAN> LIST BACKUP SUMMARY;
-- Look for SCN in output
```

**From GoldenGate extract:**
```bash
ggsci> INFO EXTRACT AUDDTEXT, DETAIL
# Look for "Current Checkpoint" SCN
```

### SCN too old error

If you get "SCN is too old" error:
- The SCN is beyond the retention of archived redo logs
- Check archive log retention: `SELECT NAME, FIRST_CHANGE# FROM V$ARCHIVED_LOG;`
- Use a more recent SCN or BEGIN NOW

### Cannot register extract with SCN

If REGISTER fails with SCN:
- Ensure integrated extract is supported
- Check database version (requires 11.2.0.4+ or 19c+)
- Verify LogMiner is configured: `SELECT * FROM DBA_LOGMNR_LOG;`

## Best Practices

1. **Always get current SCN first** before rebuilding extracts
2. **Use matching SCN** for both REGISTER and ADD EXTRACT
3. **Document the SCN** used for each extract deployment
4. **Test in non-production** before applying to production
5. **Verify archive log availability** before using old SCNs
6. **Use SCN over time** for precision and consistency
7. **Keep extract parameter files** backed up with their SCN values

## Related Tasks

- `get-current-scn` - Get current SCN from databases
- `install-audit-extract` - Install AUDITDATA and AUDITREF extracts
- `install-mis-extract` - Install MIS extract
- `goldengate-start` - Start extracts after registration
- `goldengate-stop` - Stop extracts before rebuild

## Examples with Full Commands

### Complete Fresh Install
```bash
ansible-playbook site.yml --tags goldengate-install
```

### Complete Rebuild from SCN
```bash
# 1. Get SCN
ansible-playbook site.yml --tags get-current-scn

# 2. Note output: Source Database (T1CNOM) Current SCN: 123456789

# 3. Stop processes
ansible-playbook site.yml --tags goldengate-stop

# 4. Rebuild with SCN
ansible-playbook site.yml --tags install-audit-extract \
  --extra-vars "oracle_goldengate_register_start_mode=scn \
                oracle_goldengate_register_start_scn=123456789 \
                oracle_goldengate_extract_start_mode=scn \
                oracle_goldengate_extract_start_scn=123456789"

# 5. Start processes
ansible-playbook site.yml --tags goldengate-start
```

---

For more information, see:
- `EXTRACT_START_OPTIONS_PLAN.md` - Implementation details
- `TAG_BEST_PRACTICES.md` - Tag usage guide
- Oracle GoldenGate 19c documentation
