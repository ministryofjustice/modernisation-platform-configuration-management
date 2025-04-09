# Role for creating users and groups.

## System Users

### UID and GID mapping

Ensure the same uid/gid is used across all EC2 instances.
Define mapping between user to uid, and group to gid, in `vars/`. For example:

- [default-system-gids.yml](/ansible/roles/users-and-groups/vars/default-system-gids.yml)
- [default-system-uids.yml](/ansible/roles/users-and-groups/vars/default-system-uids.yml)

A custom mapping can be created if necessary for a given business unit or application.  For example, create
`vars/hmpps-system-gids.yml` and `vars/hmpps-system-uids.yml` and set

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

## Regular Users

Only use this if the standard ssm-user will not suffice, e.g. users require their
own home directory or to use ssh over ssm.

Users should add their ssh public keys to the relevant business unit vars file, e.g.
Also assign a unique UID for consistency across servers. Suggest the username is set
to the user's GitHub id.

- [hmpps-regular-users.yml](/ansible/roles/users-and-groups/vars/hmpps-regular-users.yml)

Define group details such as group membership in relevant business unit vars file, e.g.

- [hmpps-regular-groups.yml](/ansible/roles/users-and-groups/vars/hmpps-regular-groups.yml)

Suggest the group names follow GitHub group ids.

Finally, define which users and groups to add by defining a variable in the relevant
server-type or environment_name group vars, e.g.

```
users_and_groups_regular:
  - group: studio-webops
  - group: syscon-nomis
```

To remove an existing user, just remove their group membership and re-run the role, e.g.
the below will remove `drobinson-moj` user.

```
regular_groups_members:
  studio-webops:
    # - drobinson-moj
    - Sandhya1874
    - KarenMoss1510
```

## XAuthority

You can optionally create blank .Xauthority files for all regular users by setting
following variable:

```
users_and_groups_create_xauthority: true
```

You can add this for system users (e.g. if you need to run an X tool as a particular
user) by adding `create_xauthority` to the `users_and_groups_system` variable:

```
users_and_groups_system:
  - name: oracle
    create_xauthority: true
    group: oinstall
    groups:
      - dba
      - wheel
```

## Passwords

You can set an auto-generated password from a secret as follows:

```
users_and_groups_secrets:
  users:
    secret: "/users/passwords"
    users:
      - salt: auto
      - sapprogram: auto

users_and_groups_system:
  - name: sapprogram
    group: sapprogram
    password: "{{ secretsmanager_passwords_dict['users'].passwords['sapprogram'] | password_hash('sha512', secretsmanager_passwords_dict['users'].passwords['salt']) }}"
```
