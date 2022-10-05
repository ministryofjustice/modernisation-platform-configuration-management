Role for configuring oracle secure web. The installation files are added as part of the AMI build.

Force the installation handler to run by using osw-force-install tag, e.g.

```
ansible-playbook  -i inventory_aws_ec2.yml site.yml  --limit t1-nomis-db-2 -e role=oracle-secure-web  -v --tags=osw-force-install,ec2provision
```
