# archiveupload

This is the auditupload playbook for an SSM document which uploads the audit logs from a target to an S3 bucket. 

This is not an independently callable playbook. It is called by the s3auditupload document in [modernisation-platform-environments](https://github.com/ministryofjustice/modernisation-platform-environments/blob/6b3f4c0039a641e5a54d6817cbbc22f0a7bbefea/terraform/environments/nomis/ssm-documents/templates/s3auditupload.yaml.tftmpl) repository.

Values for parameters are provided by the user in the AWS UI, not in the playbook.
