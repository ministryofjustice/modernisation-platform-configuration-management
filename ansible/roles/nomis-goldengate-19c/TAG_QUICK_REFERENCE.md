# GoldenGate Tags Quick Reference

## Test Individual Tasks

| Task | Command |
|------|---------|
| Detect database | `ansible-playbook site.yml --tags detect-database` |
| Install software | `ansible-playbook site.yml --tags install-software` |
| Install patches | `ansible-playbook site.yml --tags install-patches` |
| Configure ASM | `ansible-playbook site.yml --tags configure-asm` |
| Configure GG home | `ansible-playbook site.yml --tags configure-home` |
| Configure DB params | `ansible-playbook site.yml --tags configure-db-params` |
| Create DB users | `ansible-playbook site.yml --tags create-dbusers` |
| Configure credentials | `ansible-playbook site.yml --tags configure-credentials` |
| Deploy source objects | `ansible-playbook site.yml --tags deploy-source-objects` |
| Deploy AuditData objects | `ansible-playbook site.yml --tags deploy-auditdata-objects` |
| Deploy AuditRef objects | `ansible-playbook site.yml --tags deploy-auditref-objects` |
| Deploy MIS objects | `ansible-playbook site.yml --tags deploy-mis-objects` |
| Install Audit extract | `ansible-playbook site.yml --tags install-audit-extract` |
| Install Audit replicat | `ansible-playbook site.yml --tags install-audit-replicat` |
| Install MIS extract | `ansible-playbook site.yml --tags install-mis-extract` |
| Install MIS replicat | `ansible-playbook site.yml --tags install-mis-replicat` |
| Register Audit extract | `ansible-playbook site.yml --tags register-audit-extract` |
| Register Audit replicat | `ansible-playbook site.yml --tags register-audit-replicat` |
| Register MIS extract | `ansible-playbook site.yml --tags register-mis-extract` |
| Register MIS replicat | `ansible-playbook site.yml --tags register-mis-replicat` |
| Start Audit extract | `ansible-playbook site.yml --tags start-audit-extract` |
| Start Audit replicat | `ansible-playbook site.yml --tags start-audit-replicat` |
| Start MIS extract | `ansible-playbook site.yml --tags start-mis-extract` |
| Start MIS replicat | `ansible-playbook site.yml --tags start-mis-replicat` |
| Stop Audit extract | `ansible-playbook site.yml --tags stop-audit-extract` |
| Stop Audit replicat | `ansible-playbook site.yml --tags stop-audit-replicat` |
| Stop MIS extract | `ansible-playbook site.yml --tags stop-mis-extract` |
| Stop MIS replicat | `ansible-playbook site.yml --tags stop-mis-replicat` |
| Deploy scripts | `ansible-playbook site.yml --tags deploy-scripts` |
| Get current SCN | `ansible-playbook site.yml --tags get-current-scn` |

## Test by Phase

| Phase | Command |
|-------|---------|
| All installation | `ansible-playbook site.yml --tags goldengate-install` |
| All configuration | `ansible-playbook site.yml --tags goldengate-config` |
| Software only | `ansible-playbook site.yml --tags goldengate-software` |
| DB config only | `ansible-playbook site.yml --tags goldengate-database-config` |
| All processes | `ansible-playbook site.yml --tags goldengate-processes` |
| Start all processes | `ansible-playbook site.yml --tags goldengate-start` |
| Stop all processes | `ansible-playbook site.yml --tags goldengate-stop` |

## Test by Database

| Target | Command |
|--------|---------|
| Audit DB tasks | `ansible-playbook site.yml --tags goldengate-audit` |
| MIS DB tasks | `ansible-playbook site.yml --tags goldengate-mis` |
| Source DB objects | `ansible-playbook site.yml --tags deploy-source` |

## Test by Function

| Function | Command |
|----------|---------|
| All extract processes | `ansible-playbook site.yml --tags goldengate-extract` |
| All replicat processes | `ansible-playbook site.yml --tags goldengate-replicat` |
| Register all processes | `ansible-playbook site.yml --tags goldengate-register` |
| Start all extracts | `ansible-playbook site.yml --tags goldengate-start-extract` |
| Stop all extracts | `ansible-playbook site.yml --tags goldengate-stop-extract` |
| Start all replicats | `ansible-playbook site.yml --tags goldengate-start-replicat` |
| Stop all replicats | `ansible-playbook site.yml --tags goldengate-stop-replicat` |
| All credentials | `ansible-playbook site.yml --tags goldengate-credentials` |
| All scripts | `ansible-playbook site.yml --tags goldengate-scripts` |

## Combine Multiple Tags

```bash
# Install software and patches only
ansible-playbook site.yml --tags install-software,install-patches

# Configure database and create users
ansible-playbook site.yml --tags configure-db-params,create-dbusers

# Deploy all database objects
ansible-playbook site.yml --tags deploy-source-objects,deploy-auditdata-objects,deploy-auditref-objects,deploy-mis-objects

# Install all Audit processes
ansible-playbook site.yml --tags install-audit-extract,install-audit-replicat

# Register all Audit processes
ansible-playbook site.yml --tags register-audit-extract,register-audit-replicat
```

## Skip Specific Tasks

```bash
# Install everything except patches
ansible-playbook site.yml --tags goldengate-install --skip-tags install-patches

# Configure everything except credentials
ansible-playbook site.yml --tags goldengate-config --skip-tags configure-credentials
```

## Dry Run (Check Mode)

```bash
# Test without making changes
ansible-playbook site.yml --tags install-software --check

# Show differences that would be made
ansible-playbook site.yml --tags configure-home --check --diff
```

## List All Available Tags

```bash
ansible-playbook site.yml --list-tags
```

## Common Testing Workflows

### Test New Feature Development
```bash
# Test your specific task
ansible-playbook site.yml --tags your-new-task --check

# Then run for real
ansible-playbook site.yml --tags your-new-task
```

### Test Configuration Changes
```bash
# Test configuration changes
ansible-playbook site.yml --tags goldengate-config --check --diff

# Apply if tests pass
ansible-playbook site.yml --tags goldengate-config
```

### Test Process Installation
```bash
# Test process installation for Audit
ansible-playbook site.yml --tags install-audit-extract,install-audit-replicat --check

# Test process installation for MIS
ansible-playbook site.yml --tags install-mis-extract,install-mis-replicat --check
```

### Register Processes
```bash
# Register all processes
ansible-playbook site.yml --tags goldengate-register

# Register specific process
ansible-playbook site.yml --tags register-audit-extract
```

### Start/Stop Processes
```bash
# Start all extracts
ansible-playbook site.yml --tags goldengate-start-extract

# Stop all replicats
ansible-playbook site.yml --tags goldengate-stop-replicat

# Start specific process
ansible-playbook site.yml --tags start-audit-extract

# Stop specific process
ansible-playbook site.yml --tags stop-mis-replicat
```

### Re-deploy After Code Changes
```bash
# Re-deploy scripts after modifications
ansible-playbook site.yml --tags deploy-scripts

# Re-deploy specific database objects
ansible-playbook site.yml --tags deploy-auditdata-objects
```

## Best Practices

1. ✅ Always test with `--check` first
2. ✅ Use unique task tags for precise testing
3. ✅ Combine tags for related tasks
4. ✅ Use `--diff` to see what will change
5. ✅ Skip tags to exclude specific tasks
6. ✅ Run `--list-tags` to verify available tags
7. ✅ Document custom tags in comments
