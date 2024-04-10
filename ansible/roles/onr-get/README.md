# Overview

Gets the BOE software for ONR off the hmpp/onr s3 bucket and extracts it

# Pre-requisites

Ensure users and disks roles have already run to create /u01/ and /u02/ disks

# Example

import the role into main.yml

```
- ansible.builtin.import_role:
    name: onr-get
  tags:
    - amibuild
    - ec2provision
```
