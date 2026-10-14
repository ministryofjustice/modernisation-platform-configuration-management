# oracle_release_update

Applies an Oracle Database Release Update (DBRU) to a Grid Infrastructure and Database home using the out-of-place (clone) patching method.  Patching is split across three modes to minimise downtime.

---

## Apply Modes

### 1. `prepare-clone` *(online, no downtime)*

Clones the existing GI and DB homes into new versioned directories and applies the Release Update patch to the clones.  The live databases continue running from the original homes throughout.

Run this against **primaries first**, then standbys.

```bash
ansible-playbook playbook.yml \
  -e target_hosts=my_primarydb \
  -e apply_mode=prepare-clone
```

```bash
ansible-playbook playbook.yml \
  -e target_hosts=my_standbydb1 \
  -e apply_mode=prepare-clone
```

---

### 2. `switch-clone` *(requires downtime)*

Switches the live databases from the old homes to the patched clones, runs Datapatch, installs the OJVM patch on the primary, and updates OEM targets.

Run this against **primaries first**.  Standbys follow after `apply-ojvm-standby` (below).

```bash
ansible-playbook playbook.yml \
  -e target_hosts=my_primarydb \
  -e apply_mode=switch-clone
```

---

### 3. `apply-ojvm-standby` *(requires brief downtime on standbys)*

Installs the OJVM patch on each standby database.  Must be run **after** `switch-clone` has completed on the primary.

```bash
ansible-playbook playbook.yml \
  -e target_hosts=my_standbydb1 \
  -e apply_mode=apply-ojvm-standby
```

---

## Full Patching Sequence

```
Primary  │  prepare-clone  ──►  switch-clone
Standby  │  prepare-clone  ──────────────────►  apply-ojvm-standby
```

1. Run `prepare-clone` on primary and all standbys (can be done in parallel or ahead of time).
2. Run `switch-clone` on the primary (downtime window).
3. Run `apply-ojvm-standby` on each standby in turn.

---

## Key Variables

| Variable | Default | Description |
|---|---|---|
| `apply_mode` | `prepare-clone` | Patching phase — `prepare-clone`, `switch-clone`, or `apply-ojvm-standby` |
| `target_hosts` | *(required)* | Ansible host or group to target |
| `database_primary_sid` | *(required on primary)* | SID of the primary database |
| `database_primary_sids` | *(optional)* | List of primary SIDs when multiple databases share a home |
| `database_standby_sid` | *(required on standby)* | SID of the standby database |
| `database_standby_sids` | *(optional)* | List of standby SIDs when multiple databases share a home |
| `combo_patch_info` | `default` | Override combo patch in `<id>:<zip>:<version>` format, or `default` to use `hmpps_env_configs` |
| `gi_ru_patch_info` | `default` | Override GI patch (alternative to `combo_patch_info`) |
| `ojvm_ru_patch_info` | `default` | Override OJVM patch (alternative to `combo_patch_info`) |
| `keep_aws_snapshot` | *(unset)* | Set to a number of days to take an AWS snapshot before patching |

Patch versions for normal runs are sourced from `oracle_software` in `hmpps_env_configs`.  Use the override variables only when testing a new patch before updating the config.

---

## Multiple Databases per Host

When a server hosts more than one database in the same Oracle home, supply a list of SIDs instead of a single value:

```bash
ansible-playbook playbook.yml \
  -e target_hosts=my_primarydb \
  -e apply_mode=switch-clone \
  -e '{"database_primary_sids": ["MYDB1", "MYDB2"]}'
```

Single-SID variables (`database_primary_sid` / `database_standby_sid`) continue to work unchanged for servers with one database.
