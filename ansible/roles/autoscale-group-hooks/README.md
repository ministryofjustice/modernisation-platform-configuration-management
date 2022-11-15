Use this to create a script for calling life cycle hooks,
e.g. for either abandon or continue calls when an EC2 is initialised.

A cron is also added for when an EC2 is restored from a warm pool.

By default, the ABANDON state is used unless a file is created in
`/root/.autoscaling-lifecycle-{{ lifecycle_hook_name }}`.  The first
non-comment line is used for the state, e.g. 

```
# managed by modernisation-platform-configuration-management/ansible/roles/weblogic
CONTINUE
```
