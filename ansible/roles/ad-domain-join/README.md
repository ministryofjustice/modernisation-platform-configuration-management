This role is for joining linux instances to a domain.

# Pre-requisites

Domain join credentials are stored in a secret. The EC2 will assume a role
to retrieve the secrets, e.g. `EC2HmppsDomainSecretsRole`.

Ensure `epel` role has been run to enable installation of `jq`.

The `ad_domain_name_fqdn` variable is set to the name of the domain,
typically set in group_vars, e.g.

```
ad_domain_name_fqdn: azure.noms.root
```

The `ad_domains` is a dictionary containing details about the domain
including the domain join credentials.

e.g.

```
ad_domains:
  azure.noms.root:
    secret_account_name: hmpps-domain-services-test
    secret_role_name: EC2HmppsDomainSecretsRole
    secret_name: "/microsoft/AD/azure.noms.root/shared-passwords"
    domain_name_fqdn: azure.noms.root
    domain_name_netbios: AZURE
    domain_join_username: svc_join_domain
```

# SSH with SSM

You can use SSM to ssh to the server with your domain credentials.

Here's an example `.ssh/config` to use for a host in `hmpps-domain-services-development` account

```
Host dev-rhel85
   ProxyCommand sh -c "aws ssm start-session --target $(aws ec2 describe-instances --no-cli-pager --filters "Name=instance-state-name,Values=running" "Name=tag:Name,Values=%h" --query 'Reservations[0].Instances[0].InstanceId' --profile hmpps-domain-services-development) --document-name AWS-StartSSHSession --parameters 'portNumber=%p' --profile hmpps-domain-services-development"
   User AZURE\myusername
```

And then

```
aws sso login --profile hmpps-domain-services-development
ssh dev-rhel85
```

Sign-in with your domain credentials.
