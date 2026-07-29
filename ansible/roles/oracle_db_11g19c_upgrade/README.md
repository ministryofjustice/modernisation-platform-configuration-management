# oracle_db_11g19c_upgrade

## Tag Reference

Use these tags with `--tags` and `--skip-tags` to run logical slices of the upgrade.

| Tag | Scope | Purpose |
| --- | --- | --- |
| `upgrade_11g19c` | Playbook role tag | Run the full 11g to 19c upgrade role flow |
| `db_upgrade` | Playbook role tag | Shared top-level tag for upgrade related playbooks |
| `post_upgrade_fix` | Playbook role tag | Run post-upgrade fix role playbook |
| `preflight` | Main flow | Early role checks and setup facts |
| `discovery` | Main flow | Discover role, broker, and version facts |
| `preupgrade` | Pre-upgrade tasks | Pre-upgrade actions (APEX/OLAP/EM cleanup, ACL, etc.) |
| `preparation` | Main include | Includes the pre-upgrade action file |
| `precheck` | Pre-upgrade checks | Run Oracle preupgrade.jar checks and parsing |
| `analysis` | Precheck tasks | Report parsed output sections |
| `gate` | Precheck tasks | Assertions that gate progression |
| `upgrade` | Upgrade tasks | Core upgrade execution flow |
| `execute` | Upgrade tasks | Long-running upgrade execution steps |
| `shutdown` | Upgrade tasks | Shutdown actions |
| `startup` | Upgrade tasks | Startup actions |
| `validation` | Upgrade/preupgrade | Post-step checks and status reporting |
| `postupgrade` | Post-upgrade tasks | Post-upgrade compatibility, timezone, stats |
| `stabilization` | Main include | Includes post-upgrade action file |
| `dataguard` | Broker tasks | Data Guard Broker checks and disable path |
| `disabledg` | Broker tasks | Data Guard disable sequence |
| `listener` | Listener tasks | Listener configuration update |
| `networking` | Listener include | Network-related listener include wrapper |
| `recompile` | Pre/post tasks | Run recompilation scripts |
| `stats` | Pre/post tasks | Gather or unlock statistics tasks |

## Example Runs

Run only pre-upgrade checks:

```bash
ansible-playbook ansible/roles/oracle_db_11g19c_upgrade/db_18c_upgrade.yml --tags precheck
```

Run only upgrade execution tasks:

```bash
ansible-playbook ansible/roles/oracle_db_11g19c_upgrade/db_18c_upgrade.yml --tags upgrade,execute
```

Run only post-upgrade tasks:

```bash
ansible-playbook ansible/roles/oracle_db_11g19c_upgrade/db_18c_upgrade.yml --tags postupgrade
```

Skip Data Guard operations:

```bash
ansible-playbook ansible/roles/oracle_db_11g19c_upgrade/db_18c_upgrade.yml --skip-tags dataguard
```
