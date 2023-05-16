Also see autoscale-group-hooks

Use this role to set the state of a hook to READY.  Include this as the final
role in your ansible role list.  If there is an error somewhere along the
way, the ansible will fail and the role won't get run.  In your EC2 user data,
run ansible as a first step, and then include a second step to call the AWS
hook.

This way, the AWS hook will get called regardless of whether the ansible
succeeds or not.  And it will only be set to READY if the ansible completes
successfully.

```
roles_list:
 - autoscale-group-hooks
 - some-role
 - some-other-role
 - final-role
 - autoscale-group-hooks-state
```
