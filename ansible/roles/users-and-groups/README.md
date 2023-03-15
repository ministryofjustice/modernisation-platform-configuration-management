# Role for creating users and groups.

## System Users

### UID and GID mapping

Ensure the same uid/gid is used across all EC2 instances.
Define mapping between user to uid, and group to gid, in `vars/`. For example:

- [default-system-gids.yml](/ansible/roles/users-and-groups/vars/default-system-gids.yml)
- [default-system-uids.yml](/ansible/roles/users-and-groups/vars/default-system-uids.yml)

A custom mapping can be created if necessary.  For example, create
`vars/myapp-system-gids.yml` and `vars/myapp-system-uids.yml` and set

```
users_and_groups_system_vars_prefix: myapp
```

### Adding users and groups

Option 1. Define all the users/groups you need in the relevant AMI or
server-type group vars, and include this role in the role list.
For example:

```
users_and_groups_system:
  - name: oracle
    group: oinstall
    groups:
      - dba
      - wheel

# packages may install their own users/groups so include the role
# first to guarantee your uid/gid is used.
roles_list:
  - users-and-groups
  - packages
  ...
```

Option 2. Import from another role

```
- name: Create system users and groups
  ansible.builtin.import_role:
    name: users-and-groups
    tasks_from: add-system.yml
  vars:
    users_and_groups_system:
      - name: oracle
        group: oinstall
        groups:
          - dba
          - wheel
```

## Non-System Users

Not implemented yet.
