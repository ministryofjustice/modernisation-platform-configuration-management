# Ansible Tags Best Practices for GoldenGate Role

## Current Tag Structure Analysis

The role currently uses a **hierarchical tagging strategy** with multiple levels:

### Tag Hierarchy

```
goldengate (root - all tasks)
├── goldengate-install (installation phase)
│   ├── goldengate-software (software installation)
│   │   └── goldengate-patches (patches only)
│   ├── goldengate-config (configuration)
│   └── goldengate-database-config (DB-specific config)
│       └── goldengate-dbuser (user creation)
│
├── goldengate-config (configuration phase)
│   ├── goldengate-credentials (credential store)
│   ├── goldengate-processes (Extract/Replicat)
│   │   ├── goldengate-extract (Extract only)
│   │   └── goldengate-replicat (Replicat only)
│   └── goldengate-scripts (control scripts)
│
├── goldengate-audit (Audit DB specific)
└── goldengate-mis (MIS DB specific)
```

### Additional Functional Tags
- `deploy-source` - Source database objects
- `deploy-auditdata` - AuditData database objects
- `deploy-auditref` - AuditRef database objects
- `deploy-mis` - MIS database objects

---

## Best Practices for Tag Design

### 1. **Unique Task-Level Tags**

Each task should have a **unique tag** for independent testing:

```yaml
- name: Install Oracle GoldenGate binaries
  import_tasks: install_software.yml
  tags:
    - goldengate              # Broad scope
    - goldengate-install      # Phase scope
    - goldengate-software     # Category scope
    - install-software        # UNIQUE task-level tag ⭐
```

### 2. **Tag Naming Convention**

Follow this pattern for consistency:

| Level | Pattern | Example | Purpose |
|-------|---------|---------|---------|
| **Root** | `{role}` | `goldengate` | Run entire role |
| **Phase** | `{role}-{phase}` | `goldengate-install` | Run installation phase |
| **Category** | `{role}-{category}` | `goldengate-software` | Run software tasks |
| **Task** | `{action}-{target}` | `install-software` | Run specific task |
| **Database** | `{role}-{database}` | `goldengate-audit` | Run DB-specific tasks |
| **Function** | `deploy-{component}` | `deploy-auditdata` | Deploy specific component |

### 3. **Required Tags for Each Task**

Every task should have at minimum:

1. **Root tag** - `goldengate` (allows running all tasks)
2. **Phase tag** - `goldengate-install` or `goldengate-config`
3. **Category tag** - Functional grouping
4. **Unique task tag** - For independent execution ⭐

### 4. **Special Tags**

- `always` - Tasks that must run every time (e.g., detection, facts)
- `never` - Tasks that only run when explicitly requested
- `untagged` - Avoid this; all tasks should be tagged

---

## Recommended Tag Strategy for Your Role

### Task-Level Unique Tags (for independent testing)

Add these unique tags to each task in `main.yml`:

```yaml
---
# Detection (runs automatically)
- name: Detect local Oracle database instance
  import_tasks: detect_local_database.yml
  when: oracle_goldengate_local_db_sid is not defined or oracle_goldengate_local_db_sid == ""
  tags: 
    - always
    - detect-database          # UNIQUE ⭐

# Installation tasks
- name: Install Oracle GoldenGate binaries
  import_tasks: install_software.yml
  tags:
    - goldengate
    - goldengate-install
    - goldengate-software
    - install-software         # UNIQUE ⭐

- name: Install Oracle GoldenGate patches
  import_tasks: install_patches.yml
  tags:
    - goldengate
    - goldengate-install
    - goldengate-software
    - goldengate-patches
    - install-patches          # UNIQUE ⭐

- name: Configure Oracle ASM
  import_tasks: configure_asm.yml
  tags:
    - goldengate
    - goldengate-install
    - goldengate-config
    - configure-asm            # UNIQUE ⭐

- name: Configure GoldenGate home subdirectories and mgr
  import_tasks: configure_gg_home.yml
  tags:
    - goldengate
    - goldengate-install
    - goldengate-config
    - configure-home           # UNIQUE ⭐

- name: Configure Oracle database parameters for GoldenGate
  import_tasks: configure_database_parameters.yml
  tags:
    - goldengate
    - goldengate-install
    - goldengate-config
    - goldengate-database-config
    - configure-db-params      # UNIQUE ⭐

- name: Create GoldenGate database administrator and schema users
  import_tasks: create_gg_dbusers.yml
  when: oracle_goldengate_local_db_sid is defined and oracle_goldengate_local_db_sid != ""
  tags:
    - goldengate
    - goldengate-install
    - goldengate-database-config
    - goldengate-dbuser
    - create-dbusers           # UNIQUE ⭐

- name: Configure GoldenGate credential store
  import_tasks: configure_credential_store.yml
  tags:
    - goldengate
    - goldengate-install
    - goldengate-config
    - goldengate-credentials
    - configure-credentials    # UNIQUE ⭐

# Database object deployment
- name: Deploy Source GoldenGate database objects
  import_tasks: deploy_db_objects_source.yml
  tags:
    - goldengate
    - goldengate-install
    - goldengate-config
    - deploy-source
    - deploy-source-objects    # UNIQUE ⭐

- name: Deploy AuditRef GoldenGate database objects
  import_tasks: deploy_db_objects_auditref.yml
  tags:
    - goldengate
    - goldengate-install
    - goldengate-config
    - deploy-auditref
    - deploy-auditref-objects  # UNIQUE ⭐

- name: Deploy AuditData GoldenGate database objects
  import_tasks: deploy_db_objects_auditdata.yml
  tags:
    - goldengate
    - goldengate-install
    - goldengate-config
    - deploy-auditdata
    - deploy-auditdata-objects # UNIQUE ⭐

- name: Deploy MIS GoldenGate database objects
  import_tasks: deploy_db_objects_mis.yml
  tags:
    - goldengate
    - goldengate-install
    - goldengate-config
    - deploy-mis
    - deploy-mis-objects       # UNIQUE ⭐

# Process installation - Audit
- name: Install GoldenGate extract processes (Audit databases)
  import_tasks: install_audit_extract.yml
  when: oracle_goldengate_deploy_auditdata or oracle_goldengate_deploy_auditref
  tags:
    - goldengate
    - goldengate-config
    - goldengate-processes
    - goldengate-audit
    - goldengate-extract
    - install-audit-extract    # UNIQUE ⭐

- name: Install GoldenGate replicat processes (Audit databases)
  import_tasks: install_audit_replicat.yml
  when: oracle_goldengate_deploy_auditdata or oracle_goldengate_deploy_auditref
  tags:
    - goldengate
    - goldengate-config
    - goldengate-processes
    - goldengate-audit
    - goldengate-replicat
    - install-audit-replicat   # UNIQUE ⭐

# Process installation - MIS
- name: Install GoldenGate extract processes (MIS database)
  import_tasks: install_mis_extract.yml
  when: oracle_goldengate_deploy_mis
  tags:
    - goldengate
    - goldengate-config
    - goldengate-processes
    - goldengate-mis
    - goldengate-extract
    - install-mis-extract      # UNIQUE ⭐

- name: Install GoldenGate replicat processes (MIS database)
  import_tasks: install_mis_replicat.yml
  when: oracle_goldengate_deploy_mis
  tags:
    - goldengate
    - goldengate-config
    - goldengate-processes
    - goldengate-mis
    - goldengate-replicat
    - install-mis-replicat     # UNIQUE ⭐

# Scripts
- name: Deploy GoldenGate control scripts
  import_tasks: deploy_control_scripts.yml
  tags:
    - goldengate
    - goldengate-config
    - goldengate-scripts
    - goldengate-audit
    - goldengate-mis
    - deploy-scripts           # UNIQUE ⭐
```

---

## Testing Individual Tasks

With unique task tags, you can test each task independently:

### Run a Specific Task Only

```bash
# Test software installation only
ansible-playbook site.yml --tags install-software

# Test database parameter configuration only
ansible-playbook site.yml --tags configure-db-params

# Test credential store configuration only
ansible-playbook site.yml --tags configure-credentials

# Test audit extract installation only
ansible-playbook site.yml --tags install-audit-extract

# Test control scripts deployment only
ansible-playbook site.yml --tags deploy-scripts
```

### Run Multiple Related Tasks

```bash
# Install software and patches
ansible-playbook site.yml --tags install-software,install-patches

# Configure database and create users
ansible-playbook site.yml --tags configure-db-params,create-dbusers

# Deploy all database objects
ansible-playbook site.yml --tags deploy-source-objects,deploy-auditdata-objects,deploy-auditref-objects,deploy-mis-objects
```

### Skip Specific Tasks

```bash
# Install everything except patches
ansible-playbook site.yml --tags goldengate-install --skip-tags install-patches

# Configure everything except database parameters
ansible-playbook site.yml --tags goldengate-config --skip-tags configure-db-params
```

### Run by Phase

```bash
# Run entire installation phase
ansible-playbook site.yml --tags goldengate-install

# Run entire configuration phase
ansible-playbook site.yml --tags goldengate-config
```

### Run by Database

```bash
# Run only Audit-related tasks
ansible-playbook site.yml --tags goldengate-audit

# Run only MIS-related tasks
ansible-playbook site.yml --tags goldengate-mis
```

### Run by Function

```bash
# Run all extract/extract processes
ansible-playbook site.yml --tags goldengate-extract

# Run all replicat processes
ansible-playbook site.yml --tags goldengate-replicat

# Run all process installations
ansible-playbook site.yml --tags goldengate-processes
```

---

## Tag Usage Matrix

| Task | Unique Tag | Phase Tags | Category Tags | DB Tags |
|------|-----------|------------|---------------|---------|
| Detect DB | `detect-database` | `always` | - | - |
| Install Software | `install-software` | `goldengate-install` | `goldengate-software` | - |
| Install Patches | `install-patches` | `goldengate-install` | `goldengate-software`, `goldengate-patches` | - |
| Configure ASM | `configure-asm` | `goldengate-install`, `goldengate-config` | - | - |
| Configure Home | `configure-home` | `goldengate-install`, `goldengate-config` | - | - |
| Configure DB Params | `configure-db-params` | `goldengate-install`, `goldengate-config` | `goldengate-database-config` | - |
| Create DB Users | `create-dbusers` | `goldengate-install` | `goldengate-database-config`, `goldengate-dbuser` | - |
| Configure Credentials | `configure-credentials` | `goldengate-install`, `goldengate-config` | `goldengate-credentials` | - |
| Deploy Source Objects | `deploy-source-objects` | `goldengate-install`, `goldengate-config` | `deploy-source` | - |
| Deploy AuditData Objects | `deploy-auditdata-objects` | `goldengate-install`, `goldengate-config` | `deploy-auditdata` | - |
| Deploy AuditRef Objects | `deploy-auditref-objects` | `goldengate-install`, `goldengate-config` | `deploy-auditref` | - |
| Deploy MIS Objects | `deploy-mis-objects` | `goldengate-install`, `goldengate-config` | `deploy-mis` | - |
| Install Audit Extract | `install-audit-extract` | `goldengate-config` | `goldengate-processes`, `goldengate-extract` | `goldengate-audit` |
| Install Audit Replicat | `install-audit-replicat` | `goldengate-config` | `goldengate-processes`, `goldengate-replicat` | `goldengate-audit` |
| Install MIS Extract | `install-mis-extract` | `goldengate-config` | `goldengate-processes`, `goldengate-extract` | `goldengate-mis` |
| Install MIS Replicat | `install-mis-replicat` | `goldengate-config` | `goldengate-processes`, `goldengate-replicat` | `goldengate-mis` |
| Deploy Scripts | `deploy-scripts` | `goldengate-config` | `goldengate-scripts` | `goldengate-audit`, `goldengate-mis` |

---

## Common Testing Scenarios

### Scenario 1: Test software installation only
```bash
ansible-playbook site.yml --tags install-software --check
```

### Scenario 2: Test database configuration without installation
```bash
ansible-playbook site.yml --tags configure-db-params,create-dbusers,configure-credentials
```

### Scenario 3: Test Audit database deployment end-to-end
```bash
ansible-playbook site.yml --tags goldengate-audit
```

### Scenario 4: Re-deploy scripts after changes
```bash
ansible-playbook site.yml --tags deploy-scripts
```

### Scenario 5: Test specific process installation
```bash
# Test only AUDITDATA extract
ansible-playbook site.yml --tags install-audit-extract

# Test only MIS replicat
ansible-playbook site.yml --tags install-mis-replicat
```

### Scenario 6: Dry run with check mode
```bash
ansible-playbook site.yml --tags install-software --check --diff
```

---

## Benefits of This Approach

1. ✅ **Independent Testing**: Each task can be tested in isolation
2. ✅ **Flexible Execution**: Run any combination of tasks
3. ✅ **Clear Hierarchy**: Easy to understand tag relationships
4. ✅ **Efficient Development**: Test only what you're working on
5. ✅ **Production Safety**: Run specific tasks without full deployment
6. ✅ **Debugging**: Isolate problematic tasks quickly
7. ✅ **Documentation**: Tags serve as documentation of task purpose

---

## Tag Listing Command

To see all available tags in the role:

```bash
ansible-playbook site.yml --list-tags
```

Expected output:
```
playbook: site.yml

  play #1 (goldengate_hosts): Configure GoldenGate	TAGS: []
      TASK TAGS: [always, configure-asm, configure-credentials, configure-db-params,
                 configure-home, create-dbusers, deploy-auditdata, deploy-auditdata-objects,
                 deploy-auditref, deploy-auditref-objects, deploy-mis, deploy-mis-objects,
                 deploy-scripts, deploy-source, deploy-source-objects, detect-database,
                 goldengate, goldengate-audit, goldengate-extract, goldengate-config,
                 goldengate-credentials, goldengate-database-config, goldengate-dbuser,
                 goldengate-install, goldengate-mis, goldengate-patches,
                 goldengate-processes, goldengate-replicat, goldengate-scripts,
                 goldengate-software, install-audit-extract, install-audit-replicat,
                 install-mis-extract, install-mis-replicat, install-patches,
                 install-software]
```

---

## Recommendations

1. **Always use unique task tags** for independent testing
2. **Maintain consistent naming** across similar tasks
3. **Document tag usage** in README or playbook comments
4. **Test with `--check` first** before making changes
5. **Use `--list-tags`** to verify tag coverage
6. **Combine tags strategically** for common workflows
7. **Keep `always` tag minimal** (only detection/facts)

This tagging strategy provides maximum flexibility for development, testing, and production operations.
