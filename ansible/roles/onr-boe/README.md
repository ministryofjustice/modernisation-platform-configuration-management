# Overview

Installs BOE software for ONR

# Pre-requisites

For first time installation there needs to be an Oracle db ready to connect to. At the moment the installer is being run manually against a db that is already setup. 

A very important part of the installer is that it requires the Oracle 12c 32-bit client to be installed. 

The Business Objects Enterprise XI 3.1 installation includes a db connection check. If this fails then the installation won't proceed. Check the instance can connect to the database independently using sqlplus as the user bobj before running the installer. Any issues with the connection check will surfacein the installer logs at /<install_dir>/setup/logs/dbcheck.<timestamp>

Specifically required: 
 - oracle-12c-client # 32-bit client version only
 - oracle-tns-entries

Basically ensure other roles have already run for server_type_onr_boe

# Example

```
no_proxy="*" ansible-playbook site.yml --limit server_type_onr_boe  -e force_role=onr-boe
```
