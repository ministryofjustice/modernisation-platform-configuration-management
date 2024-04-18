# Overview

Use this role to install Oracle 12c client. Primarily for use/install on Rhel 6 ONLY!

For anything above this strongly recommend using Oracle 19c client.

# Pre-requisites


# Example

1. Install oracle 12c client -

```
 no_proxy="*" ansible-playbook site.yml --limit i-095a6de86346924dd  -e force_role=oracle-12c-client
