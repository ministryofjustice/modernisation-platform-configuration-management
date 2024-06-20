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

# Deploying multiple BOE instances

The main thing to change for pre-prod and production environments is the tag `oasys-national-reporting-environments` which is set in the terraform that defines an EC2 instance. This translates into ansible as the `onr_environment` variable so for pre-prod we'd need pp-1, pp-2 for BOE instances and for production we'd need pp-1, pp-2.

These should obviously be equivalent to the instance names i.e. pp-onr-boe-1-a and pp-onr-boe-2-b. Then in onr-boe/files we'd need configs for each of these instances like `pp_1_response_file.ini` and `pp_2_response_file.ini`. 

What we _might_ find is that it's actually possible to have the same file for both instances and just change how the values are set in the file, depending on exactly what needs changing but this is something to be tested.

# Example

```
no_proxy="*" ansible-playbook site.yml --limit server_type_onr_boe  -e force_role=onr-boe
```
