# Role for managing file shares

This role will:
- install relevant packages
- optionally retrieve credentials from SecretsManager
- mount the filesystem and add to fstab
- optionally run a keepalive check with Cloudwatch monitoring

For cloudwatch monitoring, ensure `collectd-textfile-monitoring` role is included.
Metrics will appear in `CWAgent/InstanceId,type,type_instance` where the
type_instance metric dimension is set to the value of `metric_dimension` variable.

## Mount EFS file shares

In appropriate `group_vars`, define `filesystem_mount`

Multi-AZ:
```
filesystems_mount:
  - dir: /test
    fstype: nfs
    opts: nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,nofail
    src: "{{ ansible_ec2_placement_availability_zone }}.fs-0a170471eea499c2c.efs.eu-west-2.amazonaws.com:/"
    metric_dimension: fs-0a170471eea499c2c
```

Single-AZ, e.g. in eu-west-2a
```
filesystems_mount:
  - dir: /test
    fstype: nfs
    opts: nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport,nofail
    src: "eu-west-2a.fs-0a170471eea499c2c.efs.eu-west-2.amazonaws.com:/"
    metric_dimension: fs-0a170471eea499c2c
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
    metric_dimension: amznfsxgnktcz6b
```

## Mount EC2 windows file shares

This is more or less the same as FSX. This example uses a secret configured in the same account
rather than cross-account access.

```
filesystems_domain_name_fqdn: azure.hmpp.root
filesystems_domains:
  azure.hmpp.root:
    secret_name: /ndh/pd/shared
    mount_fs_username: svc_noms_ndh_pd
filesystems_mount:
  - dir: /opt/data/interfaces/extract
    uid: 10002
    gid: 10002
    fstype: cifs
    opts: vers=3.0,_netdev,nofail,uid=10002,gid=10002,dir_mode=0755,file_mode=0755,credentials=/root/.filesystems/{{ filesystems_domain_name_fqdn }}.creds
    src: //PDPDW00057.azure.hmpp.root/NOMS_Extracts_PD$
    metric_dimension: NOMS_Extracts_PD
```

## Running Ansible

Ensure filesystem role defined in `roles_list` variable, typically defined
in group_vars server_type. Then run ansible, e.g.

```
ansible-playbook site.yml -e role=filesystems
```
