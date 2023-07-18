This role uses pywinrm to connect to Windows hosts and execute commands on them. It will execute where the EC2 instance has a tag of 'misload_target'. This needs to be the FQDN of the target instance.

Ntlm authentication is used and the username/passwords for the target instance are fetched from the AWS parameter store. The parameter stores are being created in the various nomis environment locals and locals_database.tf in the modernisation-platform-environments repo. Parameter values are being put in the stores manually from the relevant Azure key vaults.

The python scripts fetch the credentials which means they are not stored in the playbook or in the repo.