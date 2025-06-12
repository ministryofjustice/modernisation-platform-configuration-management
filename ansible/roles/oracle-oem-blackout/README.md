# Overview

Role for managing notification blackouts from within OEM. Use this role to suppress alerts during maintenance operations.

Note that the blackout code checks the value of control_management_pack_access for the environment it is running in and only creates a native OEM blackout in environments which have the Diagnostics Pack.

For environments without the Diagnostics Pack, it sets the Comment in OEM on the Host Properties against the target host(s) that are to be excluded from Monitoring Notifications.

The format of the comment is:
"Excluded from monitoring due to <EXCLUSION NAME> until <EXPIRY DATE>"

The expiry date provides an upper bound on how long the host is excluded from monitoring. This provides a safety mechanism that hosts are not excluded from monitoring indefinitely should maintenance fail or run so extremely slowly that it should be investigated. If no expiry has been set when the role is called, it will default to 30 days to ensure that the blackout is not forgotten about.

The monitoring script ( /home/oracle/admin/em/check_em_incident.sh ) checks these exclusions by querying the properties for each host target (using the emctl utility) and will not send a notification for any excluded hosts (i.e. where the Comments property for the host target is like “Excluded from monitoring”).

## Usage

When adding oracle-oem-blackout to a workflow, ensure the following:
- the workflow should checkout oracle-oem-blackout as a role from the modernisation-platform-configuration-management repo.
- the workflow should checkout secretsmanager-passwords as a role
- if used directly in a playbook as opposed to a task file, then it should be in a task block e.g.
```
- name: Start Blackout
  hosts: "{{ target_dbs }}"
  gather_facts: no
  tasks:
    - name: Start Blackout
      include_role:
        name: oracle-oem-blackout
      vars:
        target: "{{ target_dbs }}"
        blackout: "Flashback_to_{{ restore_point_name }}"
        object_type: all
        action: start
```

This creates a node-level blackout for the targets i.e. all targets on the host will be in blackout. 

Other levels of blackout can be defined through the object_type flag:
      - "oracle_database"
      - "oracle_listener"
      - "oracle_emd"
      - "osm_instance"
      - "has"
      - "host"
      - "all"

Example direct call to the role:

```
To start a 2 hour blackout for a specific host:

no_proxy="*" ansible-playbook site.yml -e force_role=oracle-oem-blackout --limit <instance-name> -e action=start -e blackout="Deployment" -e duration="02:00" -e object_type="all"

To end the blackout:

no_proxy="*" ansible-playbook site.yml -e force_role=oracle-oem-blackout --limit <instance-name> -e action=stop -e blackout="Deployment"
```

The blackout duration should be in '[days] hh:mm' format