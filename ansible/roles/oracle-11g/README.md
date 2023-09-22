# Role for installing Oracle 11G database

Ansible tags control usage.

- amibuild is used for components installed onto AMI
- ec2provision is used when provisioning an EC2 from the AMI
- ec2patch is used for updating a provisioned EC2, e.g. resizing disks.

When restoring from backup, create a new EC2 instance using the AMI backup
and either use:

- ec2provision tag if the EC2 name has changed.  This will reconfigure oracle
- ec2patch tag if the EC2 name hasn't change.  This is less disruptive.

### Pre-requisites

An `asm-passwords` placeholder SSM Parameter is created in terraform prior to
running role.  The parameter name should be
/ec2/{{ hostname }}/asm-passwords.
The initial value should contain the word "placeholder". Terraform should
ignore subsequent changes to the parameter value since this role will auto
generate a password and store it there.
