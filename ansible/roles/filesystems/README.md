# Role for managing file shares

## Mount EFS file shares

In appropriate `group_vars`, e.g.

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
