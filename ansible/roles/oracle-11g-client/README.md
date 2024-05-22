# Overview

IMPORTANT: This role doesn't _fully_ work as there are some package dependencies that are currently missing. Use the oracle-12c-client role instead!

# Pre-requisites


# Example

1. Install oracle 11g client -

```
 no_proxy="*" ansible-playbook site.yml --limit i-095a6de86346924dd  -e force_role=oracle-11g-client
