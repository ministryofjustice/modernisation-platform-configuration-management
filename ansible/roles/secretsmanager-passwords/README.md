# SecretsManager Passwords

Use this role to retrieve and/or automatically generate passwords stored in SecretsManager Secrets.

The secret itself is a JSON with following structure:

```
{
  "username1": "password1",
  "username2": "password2"
}
```

## Sharing SecretsManager Secrets across accounts

If you are not doing this, you may as well use SSM parameters.
This is tricky to setup.

The EC2 needs to assume an IAM role with the relevant permissions to retrieve
the SecretsManager secret and KMS key. There's example of how to do this
in baseline terraform code:

Account core-shared-services-production
- Holds the KMS key which encrypts the secret

Account A e.g. hmpps-oem-development
- Creates secrets and shares the resources with each relevant IAM role in the
  target accounts B,C,D etc.  See `locals_oem.tf` in hmpps-oem terraform

Account B,C,D, e.g. nomis-development, oasys-development
- Creates an IAM role which can be assumed from an EC2. See
  EC2OracleEnterpriseManagementSecretsRole in `baseline_presets` terraform module.
- Ensure this role can access KMS keys and Secrets

The ansible will assume the role (if necessary) to retrieve the secret from
another account.


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
      oem_passwords:
        account_name: "hmpps-oem-{{ environment }}"
        assume_role_name: EC2OracleEnterpriseManagementSecretsRole
        secret: "/ec2/oracle/oem/passwords"
        users:
          - agentreg: auto # password auto generated if not present
      emrep_passwords:
        account_name: "hmpps-oem-{{ environment }}"
        assume_role_name: EC2OracleEnterpriseManagementSecretsRole
        secret: "/ec2/oracle/database/EMREP/passwords"
        users:
          - sysman: # password must be set outside of code
```

The role will automatically generate passwords and update the
secret value.
The role will automatically generate passwords and update the
secret value. This will be available to access in subsequent ansible
code using the `secretsmanager_passwords_dict` fact:

```
agentregpassword: "{{ secretsmanager_passwords_dict['oem_passwords'].passwords['agentreg'] }}"
```

See OEM secrets for an example of how this is used in practice.

3. Force re-generation of password

You can force a re-generation of password by including the secret key and username
in the `secretsmanager_passwords_force_rotate` variable.  For example:

```
ansible-playbook site.yml -e role=oracle-oem-agent-setup -e secretsmanager_passwords_force_rotate=emrep_passwords:sysman --limit test-oem-a
```
