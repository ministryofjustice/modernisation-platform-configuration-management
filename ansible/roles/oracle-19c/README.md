This role installs Oracle 19c. It assumes the installation disks `\u01` and `\u02` have already been setup (with `disks` role for example).

### Pre-requisites

An `asm-passwords` placeholder SSM Parameter is created in terraform prior to
running role.  The parameter name should be
/ec2/{{ hostname }}/asm-passwords.
The initial value should contain the word "placeholder". Terraform should
ignore subsequent changes to the parameter value since this role will auto
generate a password and store it there.

### Ansible Tags

Some tasks are optional and can be included in the play by adding the appropriate tag at the command line. Currently these are:

E.g. Run `ansible-playbook` with `--tags "oracle_19c_install,pre_install,configure_asm,install_grid,install_database,post_install" " to run the Oracle install tasks

### Artefacts

The Oracle installation files should be located in an s3 bucket accessible by the remote host.  Default is located in `core-shared-services-production` account.

### Oracle User

Please ensure oracle user is created prior to running this role, e.g. via `users-and-groups` role.

### Oracle ASM disks

Oracle ASM (Automatic Storage Manager) ASMLIB is used as the volume manager for Oracle database disks rather than manual configuration with [UDEV rules](https://dsdmoj.atlassian.net/wiki/spaces/DSTT/pages/579994207/UDEV+configuraion+for+ASM+Disks). The `disks` role maps linux devices to AWS disks.  Define disk layout in host or group variables, e.g.

```
disks_partition:
  - ebs_device_name: /dev/sde
    oracle_group: data
    oracle_label: DATA01
  - ebs_device_name: /dev/sdf
    oracle_group: data
    oracle_label: DATA02
  - ebs_device_name: /dev/sdg
    oracle_group: data
    oracle_label: DATA03
  - ebs_device_name: /dev/sdh
    oracle_group: data
    oracle_label: DATA04
  - ebs_device_name: /dev/sdi
    oracle_group: data
    oracle_label: DATA05
  - ebs_device_name: /dev/sdj
    oracle_group: flash
    oracle_label: FLASH01
  - ebs_device_name: /dev/sdk
    oracle_group: flash
    oracle_label: FLASH02
```

### Issues
With el8 currently we have issue with Oracle 19c Grid ASM disks discovery with ORCL , its working with only /dev/oracleasm/disks. With ORCL it results in ORA-7445 [kgfkWaitIO] , raised SR with oracle to get fix for this issue.

### Oracle 19c RU upgrade patch post go live 
no_proxy="*" ansible-playbook site.yml -e force_role=oracle-19c --limit pd-ncr-db-2-c --tags oracle_19c_RU_upgrade
