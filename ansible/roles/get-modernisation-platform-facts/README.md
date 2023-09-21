Role for retrieving common modernisation platform secrets and SSM parameters.

Note that the `environment_management` secret stored in `modernisation_platform`
is not shared with EC2 instances. So this role relies on a copy being stored
as a SSM parameter `account_ids`.

See nomis for an example of how this parameter is created using the
`baseline` and `baseline_presets` module.

Facts are set as follows:
- `account_ids` is a map of account IDs where account name is the key

Use this if you need to reference resources from other accounts.  For example:

```
- set_fact:
     mypassword_secret_id: "arn:aws:secretsmanager:eu-west-2:{{ account_ids['nomis-test'] }}:secret:mypassword"

- set_fact:
     mypassword_secret: "{{ lookup('amazon.aws.aws_secret', mypassword_secret_id, region='eu-west-2') }}"
```
