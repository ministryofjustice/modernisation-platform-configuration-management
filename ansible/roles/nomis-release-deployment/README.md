# Overview

Use this role to deploy Nomis syscon releases

# Pre-requisites

All database Passwords are stored in SecretsManager
Release uploaded S3 bucket .

# Example





1. To deploy release on Test environments

Ensure ansible is configured on your local device and relevant AWS creds setup.
Check inventory to identify weblogic and database names:

```
ansible-inventory --graph
```

For the given environment, t1, t2, t3 etc.. there will be grouped hosts

```
  |--@server_type_nomis_db_t1:
  |  |--t1-nomis-db-1-a
  |  |--t1-nomis-db-2-a
  |--@server_type_nomis_web_t1:
  |  |--i-08ecc3e07d3783464
  |  |--i-0fedd176694815eb2
```

Set variables

```
export limit_db=t1-nomis-db-1-a
export limit_web=server_type_nomis_web_t1
```

Or you can set indiviual instances if you prefer

```
export limit_db=t1-nomis-db-1-a
export limit_web=i-08ecc3e07d3783464,i-0fedd176694815eb2
```

A. Start Outage and stop application

First sanity check ansible and server to run against

```
no_proxy="*" ansible -m shell -a "service weblogic-healthcheck status" $limit_web
```

Then run for real

```
no_proxy="*" ansible -m shell -a "service weblogic-healthcheck stop" $limit_web
echo "Waiting 2 minutes for load balancer to detect unhealthy hosts..."
sleep 120
no_proxy="*" ansible -m shell -a "service weblogic-all stop" $limit_web
no_proxy="*" ansible -m shell -a "service weblogic-node-manager start; service weblogic-server start" $limit_web
```

B. Take database restore point

WIP on these roles - After oracle-restore-point role restore_point tag to add, if streams configured app tables involved in release tag stop_streams to append. (These tags to run on DB servers)
```
no_proxy="*" ansible-playbook site.yml --limit $limit_db -e force_role=nomis-release-deployment -e restore_point_name=PRE_ROLE_RUN -e db_tns_list=T1MIS,T1CNMAUD,T1CNOM --tags create_restore_point
```

C. Deploy release on database server (DO NOT RUN FROM WEB SERVER AS ORACLE VERSIONS ARE DIFFERENT)
```
 no_proxy="*" ansible-playbook site.yml --limit t1-nomis-db-1-a  -e force_role=nomis-release-deployment --tags deploy_release
```

D. Deploy release on Web servers
```
 no_proxy="*" ansible-playbook site.yml --limit t1-nomis-web-1-a  -e force_role=nomis-release-deployment --tags deploy_release
```

E. Start aplication  on Web servers
 no_proxy="*" ansible-playbook site.yml --limit t1-nomis-web-1-a  -e force_role=nomis-release-deployment --tags start_application
```

F. Post shakedown end outage .

```
 no_proxy="*" ansible-playbook site.yml --limit t1-nomis-web-1-a  -e force_role=nomis-release-deployment --tags end_otage
```

G. Start streams if previously stopped (Run on DB server)

```
 no_proxy="*" ansible-playbook site.yml --limit t1-nomis-db-1-a  -e force_role=nomis-release-deployment --tags start_streams
```


H. Post successful validation drop the restore point (Run on DB server)

```
no_proxy="*" ansible-playbook site.yml --limit t1-nomis-db-1-a  -e force_role=nomis-release-deployment -e restore_point_name=PRE_ROLE_RUN -e db_tns_list=T1MIS,T1CNMAUD,T1CNOM --tags drop_restore_point
```
