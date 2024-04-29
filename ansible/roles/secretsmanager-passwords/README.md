# SecretsManager Passwords

Use this role to retrieve and/or automatically generate passwords stored in SecretsManager Secrets.

The secret itself is a JSON with following structure:

```
{
  "username1": "password1",
  "username2": "password2"
}
```

# Accessing Secret in same account

Permissions required for EC2 role:
- `secretsmanager:GetSecretValue`
- `secretsmanager:SetSecretValue` if setting

Example step:

```
- name: Get OEM secrets
  import_role:
    name: secretsmanager-passwords
  vars:
    secretsmanager_passwords:
      oem_passwords:
        secret: "/ec2/oracle/oem/passwords"
        users:
          - agentreg: auto # password auto generated if not present
          - sysman: # password must be set outside of code
```

# Accessing Secret in a different account

## Option 1 - EC2 IAM Role

The Secret must have a policy which grants the EC2 IAM role principal `secretsmanager:GetSecretValue`.
If this is tricky to achieve, see Option 2.

An additional variable `account_name` must be defined.  An SSM parameter
is used to defive the account id. See `get-modernisation-platform-facts` role.

Example step:

```
- name: Get OEM secrets
  import_role:
    name: secretsmanager-passwords
  vars:
    secretsmanager_passwords:
      oem_passwords:
        account_name: "hmpps-oem-{{ environment }}"
        secret: "/ec2/oracle/oem/passwords"
        users:
          - agentreg: auto # password auto generated if not present
          - sysman: # password must be set outside of code
```

## Option 2 - Dedicated IAM Role

If it is a pain to grant permissions to all EC2 roles, create a dedicated
IAM role for the purpose and set the `assume_role_name` variable.

Ansible will assume the role before attempting to retrieve the secret.

Example step:

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

