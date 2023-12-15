Role for retrieving common modernisation platform secrets and SSM parameters.

Note that the `environment_management` secret stored in `modernisation_platform`
is not shared with EC2 instances. So this role relies on a copy being stored
as a SSM parameter `account_ids`.

For applications that use baseline module (Nomis, Oasys etc.), the value
is automatically created via the `baseline` module. Otherwise, add terraform
like this

```
resource "aws_ssm_parameter" "account_ids" {
  name        = "account_ids"
  description = "Selected modernisation platform AWS account IDs for use by ansible"
  type        = "SecureString"
  key_id      = data.aws_kms_key.general_shared.arn
  value = jsonencode({
    for key, value in local.environment_management.account_ids :
    key => value if contains(["hmpps-oem-${local.environment}"], key)
  })

  tags = merge(local.tags, {
    Name = "account_ids"
  })
}
```

Facts are set as follows:
- `account_ids` is a map of account IDs where account name is the key

Use this if you need to reference resources from other accounts.  For example:

```
- set_fact:
     mypassword_secret_id: "arn:aws:secretsmanager:eu-west-2:{{ account_ids['nomis-test'] }}:secret:mypassword"

- set_fact:
     mypassword_secret: "{{ lookup('amazon.aws.aws_secret', mypassword_secret_id, region='eu-west-2') }}"
```
