# Role for managing file shares

## Mount EFS file shares

In appropriate `group_vars`, define `filesystem_mount`

Multi-AZ:
```
filesystems_mount:
  - dir: /test
    fstype: nfs
    opts: nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,nofail
    src: "{{ ansible_ec2_placement_availability_zone }}.fs-0a170471eea499c2c.efs.eu-west-2.amazonaws.com:/"
```

Single-AZ, e.g. in eu-west-2a
```
filesystems_mount:
  - dir: /test
    fstype: nfs
    opts: nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,nofail
    src: "eu-west-2a.fs-0a170471eea499c2c.efs.eu-west-2.amazonaws.com:/"
```

## Mount FSX windows file shares

Since the FSX windows file shares is joined to a domain, it is assumed
there is a SecretsManager Secret (in json key-pair format) containing
username and password to use for join. The creds are stored  on the server
so ensure this service user has minimal permissions.

The secret configuration must be included in `defaults/main.yml` for
the given domain.

Then, in appropriate `group_vars`, define `filesystem_mount` and `filesystems_domain_name_fqdn`

```
filesystems_domain_name_fqdn: azure.noms.root
filesystems_mount:
  - dir: /test2
    fstype: cifs
    opts: vers=3.1.1,rsize=130048,wsize=130048,cache=none,credentials=/root/.filesystems/{{ filesystems_domain_name_fqdn }}.creds
    src: //amznfsxgnktcz6b.azure.noms.root/share
```

## Running Ansible

Ensure filesystem role defined in `roles_list` variable, typically defined
in group_vars server_type. Then run ansible, e.g.

```
ansible-playbook site.yml -e role=filesystems
```
