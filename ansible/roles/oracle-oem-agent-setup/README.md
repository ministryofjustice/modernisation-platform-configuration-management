# Overview

Use this role to install Oracle Enterprise Manager agent on target servers 
# Pre-requisites
 
  1. OMS detail stored in environment file 
     Example entry from group_vars/environment_name_nomis_test.yml - 
      OMS_SERVER: oem.test.nomis.service.justice.gov.uk
      OEM_AGENT_VERSION: 13.5.0.0.0

  2. SSM entries for sysman and agent registration exists in account same as target. 
      Entries needed 
        - /oem/agentregpassword 
        - /oem/sysmanpassword

      
  2. For ASM monitoring SSM already has ASMSNMP password stored in below format - 

      /database/{hostname}/ASMSNMP

  3. For Database monitoring SSM already has dbsnmp password stored in below format - 

      /database/{hostname}/{db sid}/dbsnmp

# Example

Install Oracle Enterprise Manager Cloud Control 13c Release 5 OEM agent on target server

```
  no_proxy="*" ansible-playbook site.yml --limit t2-nomis-db-1-a -e force_role=oracle-oem-agent-setup
```

To Deinstall OEM agent tag needs to be speicified 
```
  no_proxy="*" ansible-playbook site.yml --limit t2-nomis-db-1-a -e force_role=oracle-oem-agent-setup --tags deinstall
```