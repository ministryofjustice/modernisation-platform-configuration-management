# Overview

Use this role to deploy Nomis syscon releases to the database.
Use nomis-weblogic role to deploy Nomis syscon releases to the web server.

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

A. Start Outage and stop Web application

First sanity check ansible and server to run against

```
no_proxy="*" ansible -m shell -a "service weblogic-healthcheck status" $limit_web
```

Then run for real. This will remove the keepalive.htm file first.  This
must be done by stopping weblogic-healthcheck service.  And then a little while
later the services are stopped.

```
no_proxy="*" ansible -m shell -a "service weblogic-healthcheck stop" $limit_web
echo "Waiting 2 minutes for load balancer to detect unhealthy hosts..."
sleep 120
no_proxy="*" ansible -m shell -a "service weblogic-all stop" $limit_web
no_proxy="*" ansible -m shell -a "service weblogic-node-manager start; service weblogic-server start" $limit_web
```

B. Take database restore point

```
no_proxy="*" ansible-playbook site.yml --limit $limit_db -e force_role=oracle-restore-point -e restore_point_name=PRE_ROLE_RUN -e db_tns_list=T1MIS,T1CNMAUD,T1CNOM --tags create_restore_point
```

C. Deploy releases on database server 

The default is to apply all patches present on the S3 bucket that follow the `last_nomis_release` variable.

```
no_proxy="*" ansible-playbook site.yml --limit $limit_db -e force_role=nomis-release-deployment --tags ec2patch
```

Alternatively, you can specify a list on the command line like this

```
no_proxy="*" ansible-playbook site.yml --limit $limit_db -e force_role=nomis-release-deployment --tag ec2patch  -e '{"nomis_releases": ["DB_V11.2.1.1.220", "DB_V11.2.1.1.221"]}' -v
```

D. Deploy releases on Web servers

The weblogic servers will use SQL to query which patches to install. Install like this:

```
no_proxy="*" ansible-playbook site.yml --limit $limit_web -e force_role=nomis-weblogic --tags ec2patch
```

E. Start application on Web servers

```
echo "Starting all weblogic services, this will take ages"
no_proxy="*" ansible -m shell -a "service weblogic-all start" $limit_web
no_proxy="*" ansible -m shell -a "service weblogic-all healthcheck" $limit_web
```

If there is issue, you can use repair to restart failed processes

```
no_proxy="*" ansible -m shell -a "service weblogic-all repair" $limit_web
```

F. Post shakedown end outage

```
no_proxy="*" ansible -m shell -a "service weblogic-healthcheck start" $limit_web
echo "Waiting 2 minutes for load balancer to detect healthy hosts..."
sleep 120
```

G. Start streams if previously stopped

# Do this manually until `oracle-streams` role is created

H. Post successful validation drop the restore point

```
no_proxy="*" ansible-playbook site.yml --limit $limit_db -e force_role=oracle-restore-point -e restore_point_name=PRE_ROLE_RUN -e db_tns_list=T1MIS,T1CNMAUD,T1CNOM --tags drop_restore_point
```
