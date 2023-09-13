Role for retrieving common modernisation platform secrets and SSM parameters.

Variables are set as follows:
- `modernisation_platform_account_id` is the account ID for `modernisation_platform` account
- `environment_management_secret` is the `environment_management` secret
- `account_ids` is a map of account IDs where account name is the key.  Part of the `environment_management` secret.

Use this if you need to reference resources from other accounts.  For example:

```
- set_fact:
     mypassword_secret_id: "arn:aws:secretsmanager:eu-west-2:{{ account_ids['nomis-test'] }}:secret:mypassword"

- set_fact:
     mypassword_secret: "{{ lookup('amazon.aws.aws_secret', mypassword_secret_id, region='eu-west-2') }}"
```
