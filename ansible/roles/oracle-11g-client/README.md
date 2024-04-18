# Overview

Use this role to install Oracle 11g client. Primarily for use/install on Rhel 6 or earlier ONLY!

# Pre-requisites


# Example

1. Install oracle 11g client -

```
 no_proxy="*" ansible-playbook site.yml --limit i-095a6de86346924dd  -e force_role=oracle-11g-client
