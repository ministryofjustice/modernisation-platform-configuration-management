# SecretsManager Passwords

Use this role to retrieve and/or automatically generate passwords stored in SecretsManager Secrets.

The secret itself is a JSON with following structure:

```
{
  "username1": "password1",
  "username2": "password2"
}
```

## Recommended Usage

1. Set placeholder value in terraform

Create a "placeholder" SecretsManager Secret in terraform.
Include the word "placeholder" in the value set by terraform.
Set lifecycle to ignore value changes.

2. Configure ansible to use this role

Either use `import_role` in the relevant place, or include the
role in the `role_list` for the server.  Define the `secretsmanager_passwords`
variable accordingly (define `account_name` if the secret is from another
account.)
Ensure the secret has been shared with EC2 instances in this account.

```
- name: Get OEM secrets
  import_role:
    name: secretsmanager-passwords
  vars:
    secretsmanager_passwords:
      - key: "oem_passwords"
        account_name: "hmpps-oem-{{ environment }}"
        secret: "/ec2/oracle/oem/passwords"
        users:
          - agentreg:
      - key: "emrep_passwords"
        account_name: "hmpps-oem-{{ environment }}"
        secret: "/ec2/oracle/database/EMREP/passwords"
        users:
          - sysman:
```

The role will automatically generate passwords and update the
secret value.

See OEM secrets for an example of how this is used in practice.
