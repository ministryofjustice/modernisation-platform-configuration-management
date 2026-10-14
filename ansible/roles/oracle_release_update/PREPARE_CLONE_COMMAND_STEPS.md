# Prepare Clone Command Steps

This document describes the steps taken when the following command is run from the `ansible/` directory:

```bash
no_proxy="*" ansible-playbook site.yml \
  -e force_role=oracle_release_update \
  -e apply_mode=prepare-clone \
  -e '{"database_primary_sids": ["QA19C", "QA11R"]}' \
  --limit dev-nomis-db19c-1-b
```

## Purpose

The command runs the `oracle_release_update` role against the single host `dev-nomis-db19c-1-b` and selects the `prepare-clone` phase.

`prepare-clone` is the online preparation phase of the Oracle Release Update process. It prepares patched clone homes for Grid Infrastructure and the Oracle database home by using Oracle out-of-place patching. It does not switch the live database to the new home. The later `switch-clone` mode performs that cutover.

## Command Inputs

| Input | Meaning |
|---|---|
| `no_proxy="*"` | Sets the environment for this command so proxy settings are bypassed. |
| `ansible-playbook site.yml` | Runs the shared Ansible site playbook. |
| `-e force_role=oracle_release_update` | Forces `site.yml` to run only the `oracle_release_update` role. The host's normal `roles_list` does not decide the role list for this run. |
| `-e apply_mode=prepare-clone` | Selects the prepare-clone phase. If not supplied, this role also defaults to `prepare-clone`. |
| `-e '{"database_primary_sids": ["QA19C", "QA11R"]}'` | Supplies the primary database SIDs that share the Oracle database home on this host. |
| `--limit dev-nomis-db19c-1-b` | Restricts the playbook run to the single inventory host `dev-nomis-db19c-1-b`. |

## High-Level Flow

1. `site.yml` starts and is limited to `dev-nomis-db19c-1-b`.
2. `force_role=oracle_release_update` makes the playbook include only the `oracle_release_update` role.
3. The top-level role includes the nested implementation role at `oracle_release_update/oracle_release_update`.
4. The nested role validates `apply_mode` and identifies this as a primary-database run because `database_primary_sids` is supplied.
5. The role resolves patch information from the primary host's `oracle_software` configuration.
6. The Release Update software is downloaded and unpacked if it is not already present.
7. Current and target GI and DB versions and homes are gathered.
8. The role checks for restore points and active Oracle out-of-place patching session files.
9. If required, the role prepares the Grid Infrastructure clone home.
10. If required, the role prepares the database clone home.
11. The role reconfigures Oracle Secure Backup Web Services files for the cloned DB home.
12. The live database remains on the original Oracle home until `switch-clone` is run later.

## Role Files Run by This Command

The table below maps the command flow to the playbook and role files that are used. Some files are included only when their `when` conditions are met.

| Step | File | When it runs | What it does |
|---|---|---|---|
| Playbook entry | `site.yml` | Always | Starts the play, applies `--limit dev-nomis-db19c-1-b`, validates the Ansible version for older OS versions, calculates `roles_to_run`, and includes the requested role. |
| Role wrapper | `roles/oracle_release_update/tasks/main.yml` | Always when `force_role=oracle_release_update` is used | Includes the nested implementation role `oracle_release_update/oracle_release_update`. |
| Role defaults | `roles/oracle_release_update/oracle_release_update/defaults/main.yml` | Loaded automatically by Ansible | Provides defaults such as `oracle_patch_directory`, `dependencies_bucket`, `source_gi_home`, `target_gi_home`, `source_db_home`, and `target_db_home`. |
| Main role flow | `roles/oracle_release_update/oracle_release_update/tasks/main.yml` | Always | Validates `apply_mode`, resolves primary/standby role, normalises SIDs, resolves patch variables, runs pre-checks, and controls which prepare/switch/OJVM task files are included. |
| Copy patch software | `roles/oracle_release_update/oracle_release_update/tasks/copy_RU_software.yml` | Always from the main role | Downloads and unpacks the configured Release Update software if it is not already present. |
| Version and home discovery | `roles/oracle_release_update/oracle_release_update/tasks/get_versioning_information.yml` | Always from the main role | Finds current GI/DB versions and homes, parses the target patch version, sets target GI/DB homes, checks whether target homes already exist, and determines the required OPatch version. |
| GI prepare clone | `roles/oracle_release_update/oracle_release_update/tasks/prepare_clone.yml` | Only if `source_gi_version < target_gi_version`, `apply_mode == prepare-clone`, and `target_gi_home` does not exist | Runs the out-of-place clone preparation for Grid Infrastructure. |
| DB prepare clone | `roles/oracle_release_update/oracle_release_update/tasks/prepare_clone.yml` | Only if `source_db_version < target_db_version`, `apply_mode == prepare-clone`, and `target_db_home` does not exist | Runs the out-of-place clone preparation for the database home. |
| OPatch upgrade | `roles/oracle_release_update/oracle_release_update/tasks/upgrade_opatch.yml` | Included by `prepare_clone.yml` for each home that is being prepared | Checks the installed OPatch version, downloads a suitable OPatch zip if needed, upgrades OPatch if required, fixes permissions, and verifies the version. |
| Inactive patch cleanup | `roles/oracle_release_update/oracle_release_update/tasks/delete_inactive_patches.yml` | Included by `prepare_clone.yml` for each home that is being prepared | Checks OPatch inactive RU patch retention and deletes inactive patches when required. |
| OOP session-cookie workaround | `roles/oracle_release_update/oracle_release_update/tasks/session_cookie_workaround.yml` | Included by `prepare_clone.yml` after a successful prepare-clone run for a home | Finds `oopsessioninfo.ser` files under the source home `.opatchauto_storage` area. |
| Complete session cookies | `roles/oracle_release_update/oracle_release_update/tasks/complete_session_cookies.yml` | Included by `session_cookie_workaround.yml` for each discovered cookie file | Changes a stuck final `ACTIVE` status to `COMPLETED` after a successful prepare-clone task. |
| OSBWS reinstall | `roles/oracle_release_update/oracle_release_update/tasks/reinstall_osbws.yml` | Runs when `source_db_version < target_db_version` and `apply_mode == prepare-clone` | Prepares the Oracle Secure Backup Web Services wallet, config, and library files for the target DB home. |

These files are present in the role but are not normally included by this command because `apply_mode=prepare-clone`:

| File | Why it is skipped for this command |
|---|---|
| `roles/oracle_release_update/oracle_release_update/tasks/switch_clone.yml` | Only included when `apply_mode == switch-clone`. |
| `roles/oracle_release_update/oracle_release_update/tasks/install_ojvm_ru.yml` | Only included during primary `switch-clone` or standby `apply-ojvm-standby`. |
| `roles/oracle_release_update/oracle_release_update/tasks/update_listener.yml` | Included only inside the `switch-clone` post-switch block. |
| `roles/oracle_release_update/oracle_release_update/tasks/upgrade_rman_catalog.yml` | Included only inside the `switch-clone` post-switch block when an RMAN catalog database is configured. |
| `roles/oracle_release_update/oracle_release_update/tasks/shutdown_database.yml` | Used by switch/OJVM flows, not by this prepare-clone command. |
| `roles/oracle_release_update/oracle_release_update/tasks/startup_database.yml` | Used by switch/OJVM flows, not by this prepare-clone command. |
| `roles/oracle_release_update/oracle_release_update/tasks/disable_adg.yml` | Used by later switch/OJVM flows, not by this prepare-clone command. |
| `roles/oracle_release_update/oracle_release_update/tasks/enable_adg.yml` | Used by later switch/OJVM flows, not by this prepare-clone command. |
| `roles/oracle_release_update/oracle_release_update/tasks/manage_blackout.yml` | Used by later switch/OJVM flows, not by this prepare-clone command. |
| `roles/oracle_release_update/oracle_release_update/tasks/update_asm_compatibility.yml` | Used by later switch/OJVM flows, not by this prepare-clone command. |
| `roles/oracle_release_update/oracle_release_update/tasks/update_oracle_restart.yml` | Used by later switch/OJVM flows, not by this prepare-clone command. |

## Detailed Steps

### 1. Playbook selection and host limit

The playbook in `site.yml` targets `{{ target | default('all') }}`. This command does not set `target`, so the play would normally target all hosts. The `--limit dev-nomis-db19c-1-b` argument then restricts the actual run to that one host.

At the start of the play, `site.yml` checks for an unsupported Ansible version on RHEL or Oracle Linux 6 hosts. If the remote host is RHEL6 or Oracle Linux 6 and Ansible is 2.13 or newer, the play fails immediately. Otherwise it continues.

### 2. Role list calculation

`site.yml` builds a `roles_defined` fact from the host's `roles_list` inventory variable, defaulting to an empty list if the host has no `roles_list`.

Because the command supplies `force_role=oracle_release_update`, `site.yml` sets:

```yaml
roles_to_run:
  - oracle_release_update
```

This bypasses the normal role selection that would otherwise use `roles_list` or `-e role=...`.

The playbook then loops over `roles_to_run` and includes the `oracle_release_update` role.

### 3. Top-level role wrapper

The top-level `oracle_release_update` role is a wrapper. Its task file includes the nested role:

```text
oracle_release_update/oracle_release_update
```

The nested role contains the actual patching logic.

### 4. Apply mode validation

The nested role first ensures `apply_mode` has a value. If it is not supplied, it sets:

```yaml
apply_mode: prepare-clone
```

For this command, `apply_mode` is already set to `prepare-clone`.

The role then validates that the value is one of:

- `prepare-clone`
- `switch-clone`
- `apply-ojvm-standby`

If another value is supplied, the role fails with `Invalid Apply Mode`.

### 5. Database role and SID handling

Because `database_primary_sids` is defined, the role sets:

```yaml
database_role: primary
```

It then normalises the supplied SIDs into the list used by later tasks:

```yaml
oracle_db_sids:
  - QA19C
  - QA11R
```

The automatic database-role detection script is not needed for this command, because the command explicitly identifies the supplied SIDs as primary SIDs.

For non-Delius environments, the role resolves the primary host directly from the inventory hostname because this is a primary run:

```yaml
primary_host_group: dev-nomis-db19c-1-b
primary_host: dev-nomis-db19c-1-b
```

The role then gathers memory facts. These facts are only relevant to later conditional FSFO logic.

### 6. Patch variable setup

The role normalises these patch override variables:

- `gi_ru_patch_info`
- `ojvm_ru_patch_info`
- `combo_patch_info`

The command does not supply any of them, so they default to `default`.

Because no patch override is used, the role reads the patch configuration from `hostvars[primary_host].oracle_software`. In the NOMIS development group variables this is currently:

```yaml
oracle_software:
  version: "19.28"
  combo_patch: p37952382_190000_Linux-x86-64.zip
  opatch:
    version: 12.2.0.1.46
    filename: p6880880_190000_Linux-x86-64.12.2.0.1.46.zip
```

From this, the role derives:

```yaml
combo_patch_id: "37952382"
COMBO_RU: p37952382_190000_Linux-x86-64.zip
expected_version: "19.28"
```

The role also sets `fsfo_mode` from the primary host, defaulting to `disabled` when it is not defined.

### 7. Optional AWS snapshot

The role can create an AWS snapshot before preparing the clone, but only when `keep_aws_snapshot` is set.

This command does not set `keep_aws_snapshot`, so the snapshot role is skipped.

### 8. Copy and unpack Release Update software

The role includes `copy_RU_software.yml`.

For a combo patch, this task downloads the zip file from the dependencies S3 bucket into the Oracle patch directory:

```text
s3://<dependencies_bucket>/dependencies/oracle/rdbms/p37952382_190000_Linux-x86-64.zip
```

The default patch directory is:

```text
/u02/stage
```

The resulting zip path is:

```text
/u02/stage/p37952382_190000_Linux-x86-64.zip
```

The task then unpacks it under:

```text
/u02/stage/37952382
```

Both the download and unarchive operations use `creates`, so they are skipped if the zip file or unpacked patch directory already exists.

### 9. Identify patch IDs inside the combo patch

Because `combo_patch_id` is defined, the role inspects the combo patch README:

```text
/u02/stage/37952382/README.html
```

It extracts:

- the GI / DB Release Update patch number, stored as `combo_gi_patch_id`
- the OJVM Release Update patch number, stored as `ojvm_patch_id`

The `prepare-clone` phase uses the GI / DB Release Update patch inside the combo patch. OJVM is not applied during this command; OJVM is handled during `switch-clone` for primaries or `apply-ojvm-standby` for standbys.

### 10. Gather current version and home information

The role includes `get_versioning_information.yml`.

It gathers the current GI version by setting `ORACLE_SID=+ASM`, running `oraenv`, and reading `sqlplus -v`.

It gathers the current GI home by setting `ORACLE_SID=+ASM`, running `oraenv`, and reading `$ORACLE_HOME`.

It gathers the current database version by running `sqlplus -v` from the oracle environment.

It gathers the current database home by reading `$ORACLE_HOME` from the oracle environment.

The role stores these as:

```yaml
source_gi_version: <current GI version>
source_gi_home: <current GI home>
source_db_version: <current DB version>
source_db_home: <current DB home>
```

The role defaults currently include:

```yaml
source_gi_home: /u01/app/oracle/product/19c/gridhome_1
source_db_home: /u01/app/oracle/product/19c/db_1
```

If those variables are already defined from defaults or inventory, they are kept. Otherwise they are set from the values discovered on the host.

### 11. Determine target version and homes

The role parses the patch README to determine the target Release Update version. For this command, the target must match the configured `expected_version` of `19.28`.

If the README version cannot be determined, or if it does not exactly match `expected_version`, the run fails.

The role then sets:

```yaml
target_gi_version: <version from patch README>
target_db_version: <same as target_gi_version>
```

The role can generate target homes by replacing the versioned portion of the source home path with the target version. However, this role also has default target home values:

```yaml
target_gi_home: /u01/app/grid/product/19.27.0/grid
target_db_home: /u01/app/oracle/product/19.27.0/db
```

If those defaults are in effect and not overridden elsewhere, those paths are used. If the target home variables are not already defined, the role derives them from the current source homes and the target patch version.

The role checks whether each target home already exists:

```yaml
stat_target_gi_home
stat_target_db_home
```

In `prepare-clone` mode, an existing target home causes the prepare step for that home to be skipped.

### 12. Determine required OPatch version

The role reads the patch README to find the minimum OPatch version required by the patch.

It compares the README value with the configured OPatch value under `oracle_software.opatch`. The role chooses the greater of the two and stores it as:

```yaml
minimum_opatch_version
```

If the role cannot determine a minimum OPatch version, it fails before patching.

### 13. Restore point and OOP session checks

The role counts restore points for all SIDs in `oracle_db_sids`:

```text
QA19C QA11R
```

Restore points only cause a failure during `switch-clone`, so in this `prepare-clone` run they are counted but do not stop the run.

The role then checks for Oracle out-of-place patching session files under both source homes:

```text
<source_gi_home>/.opatchauto_storage/$(hostname)/oopsessioninfo.ser
<source_db_home>/.opatchauto_storage/$(hostname)/oopsessioninfo.ser
```

For each file, the role runs `strings` and checks the final line. If the file does not exist, the role treats the status as `COMPLETED`. If the final line is anything other than `COMPLETED`, the run fails with one of these messages:

```text
Active OOP Session file exists for <source_gi_home>
Active OOP Session file exists for <source_db_home>
```

This prevents a new out-of-place patching session starting while Oracle appears to have an active or incomplete previous session.

### 14. Prepare the Grid Infrastructure clone home

The role prepares the GI clone only when all of these conditions are true:

- `source_gi_version` is lower than `target_gi_version`
- `apply_mode` is `prepare-clone`
- `stat_target_gi_home.stat.exists` is false

If any condition is false, the GI prepare-clone task is skipped.

When it runs, the role includes `prepare_clone.yml` with:

```yaml
source_home: "{{ source_gi_home }}"
target_home: "{{ target_gi_home }}"
target_version: "{{ target_gi_version }}"
```

Inside `prepare_clone.yml`, the role performs these steps for the GI home:

1. Checks the current OPatch version in `{{ source_home }}/OPatch`.
2. Lists available OPatch zip files in the dependencies S3 bucket.
3. Fails if no suitable OPatch software is available.
4. Upgrades OPatch if the installed version is below `minimum_opatch_version`.
5. Normalises OPatch permissions.
6. Verifies that the required OPatch version is now installed.
7. Deletes inactive patches if OPatch reports more inactive RU patches than the configured retention count.
8. Writes `/tmp/home_map.properties` containing `{{ source_home }}={{ target_home }}`.
9. Runs `opatchauto apply ... -analyze ... -outofplace` as root to analyse conflicts.
10. Waits asynchronously for the analysis job to finish.
11. Parses the analysis output for conflicting or superseded patches.
12. Removes conflicts from the list if they are previous DBRUs, already included in the target DBRU, or have replacement patch files defined for the target version.
13. Fails if unresolved conflicting patches remain.
14. Runs `opatchauto apply ... -prepare-clone -force_conflict -logLevel ALL` as root.
15. Waits asynchronously for the prepare-clone job to finish.
16. Prints the prepare-clone stdout.
17. Runs the session-cookie workaround to mark stuck `ACTIVE` OOP session files as `COMPLETED` when the prepare-clone task itself succeeded.

The `opatchauto` patch location uses either a standalone superset patch or, for this command, the GI patch inside the combo patch:

```text
/u02/stage/37952382/<combo_gi_patch_id>
```

### 15. Check OSBWS library ownership before DB clone

Before preparing the database home, the role checks for Oracle Secure Backup Web Services library files at:

```text
<source_db_home>/lib/libosbws.so
<target_db_home>/lib/libosbws.so
```

For any existing file, it normalises ownership and permissions to:

```text
owner: oracle
group: oinstall
mode: u=rwx,g=rx,o=rx
```

This is done only in `prepare-clone` mode.

### 16. Prepare the database clone home

The role prepares the database clone only when all of these conditions are true:

- `source_db_version` is lower than `target_db_version`
- `apply_mode` is `prepare-clone`
- `stat_target_db_home.stat.exists` is false

If any condition is false, the DB prepare-clone task is skipped.

When it runs, the role includes `prepare_clone.yml` again, this time with:

```yaml
source_home: "{{ source_db_home }}"
target_home: "{{ target_db_home }}"
target_version: "{{ target_db_version }}"
```

The same prepare flow described for GI is then run against the database home:

1. Upgrade OPatch if required.
2. Delete inactive patches if required.
3. Create `/tmp/home_map.properties` for the DB source and target home.
4. Run `opatchauto apply ... -analyze ... -outofplace`.
5. Parse and validate patch conflicts.
6. Run `opatchauto apply ... -prepare-clone -force_conflict -logLevel ALL`.
7. Wait for completion.
8. Apply the OOP session-cookie workaround if the clone completed successfully.

The result is a cloned database Oracle home patched to the target Release Update, ready for a later `switch-clone` run.

### 17. Reinstall Oracle Secure Backup Web Services files

After the database prepare-clone decision, the role includes `reinstall_osbws.yml` when:

- `source_db_version` is lower than `target_db_version`
- `apply_mode` is `prepare-clone`

This step is not conditional on whether the target DB home already existed. If the source DB version is lower than the target version, the OSBWS reinstall step runs in prepare-clone mode.

The OSBWS task:

1. Reads `$ORACLE_BASE` from the oracle user's environment.
2. Ensures the parent wallet directory exists at `$ORACLE_BASE/wallets`.
3. Sets the wallet directory to `$ORACLE_BASE/wallets/osbws_wallet`.
4. Checks whether that wallet directory already exists.
5. If the wallet does not exist there, copies `{{ source_home }}/dbs/osbws_wallet` to the new wallet location.
6. Ensures `{{ target_home }}/dbs/osbws.ora` exists, copying it from the source home if needed.
7. Fails if `osbws.ora` is missing from both the source and target homes.
8. Updates `OSB_WS_WALLET` in `{{ target_home }}/dbs/osbws.ora` to point to the shared wallet directory.
9. Updates `/home/oracle/admin/rman_scripts/osbws_duplicate.ora` if that file exists.
10. Unzips `{{ target_home }}/lib/osbws_linux64.zip` into `{{ target_home }}/lib`.

This prepares the cloned database home for RMAN backup integration after the later home switch.

### 18. Tasks skipped in prepare-clone mode

Because this command uses `apply_mode=prepare-clone`, the role does not run the main switch or OJVM actions.

The following areas are skipped:

- switching Grid Infrastructure to the cloned home
- switching the database to the cloned home
- updating `/home/oracle/.bash_profile` to the new database home
- updating listener configuration for the new home
- updating RMAN default tape channels as part of switch-clone
- installing the OJVM Release Update
- unlocking database accounts after switch-clone
- preparing and applying OEM target updates for the new home
- removing OOP session files from target homes, because that cleanup only runs in `switch-clone` or `apply-ojvm-standby`

The role still checks the OEM agent status and starts it if the agent is reported as not running. That check is not limited to `switch-clone`.

### 19. Possible FSFO follow-up

At the end of the role there is a conditional FSFO re-enable block. In `prepare-clone` mode it only applies when all of these are true:

- this is a primary database run
- total memory is less than or equal to 8192 MB
- `fsfo_mode` is `enabled`, `observe`, or `observer`
- the application has a high availability count greater than zero

If those conditions are not met, this block is skipped.

### 20. End state after a successful run

After a successful run:

- the Release Update software is present under `/u02/stage`
- the GI / DB patch ID inside the combo patch has been identified
- OPatch has been upgraded in source homes if required
- inactive patches have been removed if required
- the GI clone home has been prepared if the current GI version was below the target and the target GI home did not already exist
- the DB clone home has been prepared if the current DB version was below the target and the target DB home did not already exist
- OSBWS wallet and configuration files have been prepared for the target DB home
- the live database has not been switched to the cloned home
- OJVM has not been applied by this command

The next planned patching phase for the primary host is:

```bash
no_proxy="*" ansible-playbook site.yml \
  -e force_role=oracle_release_update \
  -e apply_mode=switch-clone \
  -e '{"database_primary_sids": ["QA19C", "QA11R"]}' \
  --limit dev-nomis-db19c-1-b
```

## Common Failure Points

### Active OOP session file exists

The run fails before patching if an out-of-place patching session cookie exists and does not end in `COMPLETED`:

```text
<source_home>/.opatchauto_storage/$(hostname)/oopsessioninfo.ser
```

This usually means Oracle believes a previous out-of-place patching session is still active or did not clean up correctly. The role intentionally stops rather than starting another OOP session on top of it.

### Target home already exists

If a target home already exists, the prepare-clone task for that home is skipped. This can be expected after a previous successful prepare-clone run.

### Patch README version mismatch

If the version parsed from the patch README does not match the configured `oracle_software.version`, the role fails before cloning.

### Unresolved patch conflicts

If the `opatchauto -analyze -outofplace` output reports conflicts that are not previous DBRUs, not included in the target DBRU, and not replaced by configured compatible patches, the role fails and reports the unresolved patch IDs.
