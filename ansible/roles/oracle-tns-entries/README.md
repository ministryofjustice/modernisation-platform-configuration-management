# Overview

Use this role to add TNS entries on database, application & client servers. 

# Pre-requisites

Ensure `tns_entries` variable is configured with all TNS entries. For TAF entries with mutiple hosts, specify servers seperated by @ in hosts file. 

ex: 
tns_entries:
  - { name: CNOMT1, port: 1521, host_list: t1or-a.test.nomis.service.justice.gov.uk@t1or-b.test.nomis.service.justice.gov.uk, service_name: OR_TAF }


# Example

1. Add tns entries by running role

```
no_proxy="*" ansible-playbook site.yml --limit i-0a6da49ac3861c731  -e force_role=oracle-tns-entries
```