# Overview

Installs BOE software for ONR

# Pre-requisites

Ensure other roles have already run for server_type_onr_boe

# Example

```
no_proxy="*" ansible-playbook site.yml --limit server_type_onr_boe  -e force_role=onr-boe
```
