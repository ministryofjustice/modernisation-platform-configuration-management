# SSM Passwords

Use this role to retrieve and/or automatically generate passwords stored in SSM Parameter SecretString

The secret itself is a JSON with following structure:

```
{
  "username1": "password1",
  "username2": "password2"
}
```

## Recommended Usage

1. Set placeholder value in terraform

Create a "placeholder" SSM Parameter SecretString in terraform.
Include the word "placeholder" in the value set by terraform.
Set lifecycle to ignore value changes.
Any of these modules will do this for you:
- `ec2-instance`
- `ec2-autoscaling-group`
- `baseline`

2. Configure ansible to use this role

Either use `import_role` in the relevant place, or include the
role in the `role_list` for the server.  Define the `ssm_passwords`
variable accordingly

```
- name: Get OEM SSM passwords
  import_role:
    name: secretsmanager-passwords
  vars:
    ssm_passwords:
      - key: "oem_passwords"
        parameter: "/ec2/oracle/oem/passwords"
        users:
          - agentreg:
      - key: "emrep_passwords"
        parameter: "/ec2/oracle/database/EMREP/passwords"
        users:
          - sysman:
```

The role will automatically generate passwords and update the
secret value.

See OEM secrets for an example of how this is used in practice.

3. Force re-generation of password

You can force a re-generation of password by including the secret key and username
in the `ssm_passwords_force_rotate` variable.  For example:

```
ansible-playbook site.yml -e role=oracle-oem-agent-setup -e ssm_passwords_force_rotate=emrep_passwords:sysman --limit test-oem-a
```
