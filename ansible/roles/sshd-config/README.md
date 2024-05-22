# sshd-config role

Update SSHD config with given settings defined in defaults.

Set `sshd_config_mode` to control which settings are applied.

## SSH over SSM

This is the default. KeyPair auth only

```
sshd_config_mode: default
```

## Domain Joined

Set following for password auth

```
sshd_config_mode: domain_joined
```
