# Overview

Use this role to deploy Nomis syscon releases 

# Pre-requisites

All database Passwords are stored in SSM parameter store. 
Release uploaded S3 bucket . 

# Example

1. To deploy release on Test environments 

A. Start Outage and stop application (These tags to run on web servers)
```
 no_proxy="*" ansible-playbook site.yml --limit t3-nomis-web-b  -e force_role=nomis-release-deployment --tags start_outage,stop_application
```

B. WIP on these roles - After oracle-restore-point role restore_point tag to add, if streams configured app tables involved in release tag stop_streams to append. (These tags to run on DB servers)
```
 no_proxy="*" ansible-playbook site.yml --limit t3-nomis-db-1  -e force_role=nomis-release-deployment --tags restore_point,stop_streams
```


C. Deploy release on database server (DO NOT RUN FROM WEB SERVER AS ORACLE VERSIONS ARE DIFFERENT)
```
 no_proxy="*" ansible-playbook site.yml --limit t3-nomis-db-1  -e force_role=nomis-release-deployment --tags deploy_release
```

D. Deploy release on Web servers 
```
 no_proxy="*" ansible-playbook site.yml --limit t3-nomis-web-b  -e force_role=nomis-release-deployment --tags deploy_release
```

E. Start aplication  on Web servers 
 no_proxy="*" ansible-playbook site.yml --limit t3-nomis-web-b  -e force_role=nomis-release-deployment --tags start_application 
```

F. Post shakedown end outage . 

```
 no_proxy="*" ansible-playbook site.yml --limit t3-nomis-web-b  -e force_role=nomis-release-deployment --tags end_otage 
```

G. Start streams if previously stopped (Run on DB server)
 
```
 no_proxy="*" ansible-playbook site.yml --limit t3-nomis-db-1  -e force_role=nomis-release-deployment --tags start_streams
```


H. Post confirmation (Run on DB server)

```
 no_proxy="*" ansible-playbook site.yml --limit t3-nomis-db-1  -e force_role=nomis-release-deployment --tags drop_restore_point
```