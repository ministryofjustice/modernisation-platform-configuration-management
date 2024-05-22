# Overview

Use this role to install Oracle 12c 32 bit client. Primarily for use/install on Rhel 6 ONLY!

For anything above this strongly recommend using Oracle 19c client.

64-bit client file vars are `client_software: V839967-01.zip` _however_ this role is not designed to install 64-bit client because by default the Oasys National Reporting Business Objects Enterprise XI 3.1 server is 32-bit and requires the 32-bit client libs to connect to the Oracle ONR databases.

# Pre-requisites

Pre-requisites are included in the install_client.yml file in the tasks directory.

# Example

1. Install oracle 12c client -

```
 no_proxy="*" ansible-playbook site.yml --limit i-095a6de86346924dd  -e force_role=oracle-12c-client
